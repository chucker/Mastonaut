//
//  ShareViewController.swift
//  QuickToot
//
//  Created by Bruno Philipe on 14.09.19.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2019 Bruno Philipe.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

import Cocoa
import CoreTootin
import Logging
import LoggingOSLog
import MastodonKit

class ShareViewController: NSViewController, UserPopUpButtonDisplaying
{
	private var logger: Logger!

	private let persistence = Persistence()
	private let keychain = Keychain()
	private let urlSession = URLSession(configuration: .forClients)
	private lazy var instanceService = InstanceService(urlSessionConfiguration: .forClients,
	                                                   keychainController: keychain.keychainController,
	                                                   accountsService: accountsService)

	private lazy var accountsService: AccountsService = .init(context: persistence.persistentContainer.viewContext,
	                                                          keychainController: keychain.keychainController)

	@IBOutlet private unowned var sendButton: NSButton!
	@IBOutlet private unowned var contentStackView: NSStackView!
	@IBOutlet private unowned var textView: BaseComposerTextView!
	@IBOutlet private unowned var remainingCountLabel: NSTextField!
	@IBOutlet internal private(set) unowned var currentUserPopUpButton: NSPopUpButton!
	@IBOutlet private unowned var audiencePopupButton: NSPopUpButton!
	@IBOutlet private unowned var attachmentsContainerView: NSView!
	@IBOutlet private unowned var submitStatusIndicator: NSProgressIndicator!

	@IBOutlet private unowned var attachmentsSubcontroller: AttachmentsSubcontroller!

	private lazy var userPopUpButtonController = UserPopUpButtonSubcontroller(display: self,
	                                                                          accountsService: accountsService)

	private var audienceSelection: Visibility = Visibility.make(from: Preferences.defaultStatusAudience)
	private var observations: [NSKeyValueObservation] = []

	private var textElementsToInsert: [String] = []

	// MARK: Posting Service

	private var postingServiceObservations: [NSKeyValueObservation] = []
	private var postingService: PostingService?
	{
		didSet
		{
			postingServiceObservations.removeAll()

			guard let service = postingService else { return }

			service.set(status: statusTextContent)

			postingServiceObservations.observe(service, \.characterCount, sendInitial: true)
			{ [weak self] _, _ in
				self?.updateRemainingCountLabel()
			}

			postingServiceObservations.observe(service, \.submitTaskFuture)
			{ [weak self] _, _ in
				self?.updateSubmitEnabled()
				self?.submitStatusIndicator.setAnimating(self?.hasActiveTasks ?? false)
			}
		}
	}

	// MARK: Account Search Service

	private var accountSearchService: AccountSearchService?
	{
		didSet
		{
			textView.suggestionsProvider = accountSearchService
		}
	}

	// MARK: State Management

	private let statusCharacterLimit = 500
	private var hasValidTextContents: Bool { return (1 ..< statusCharacterLimit).contains(totalCharacterCount) }
	private var hasAttachments: Bool { return !attachmentsSubcontroller.attachments.isEmpty }
	private var hasActiveUploadTasks: Bool { return attachmentsSubcontroller.attachmentUploader.hasActiveTasks }
	private var hasActiveSubmitTask: Bool { return postingService?.isSubmiting == true }
	private var hasActiveTasks: Bool { return hasActiveSubmitTask || hasActiveUploadTasks }

	private var canSubmitStatus: Bool
	{
		return (hasValidTextContents || hasAttachments) && !hasActiveTasks && client != nil
	}

	private var totalCharacterCount: Int
	{
		return postingService?.characterCount ?? 0
	}

	private var statusTextContent: String
	{
		return textView.attributedString().string
	}

	internal func updateSubmitEnabled()
	{
		sendButton.isEnabled = canSubmitStatus
	}

	private func updateRemainingCountLabel()
	{
		let remainingCount = statusCharacterLimit - totalCharacterCount
		remainingCountLabel.integerValue = remainingCount
		remainingCountLabel.textColor = .labelColor(for: remainingCount)

		updateSubmitEnabled()
	}

	// MARK: Client

	var currentUser: UUID?
	{
		get { return currentAccount?.uuid }
		set { currentAccount = newValue.flatMap { accountsService.account(with: $0) } }
	}

	private var client: ClientType?
	{
		didSet
		{
			attachmentsSubcontroller.client = client
			postingService = client.map { PostingService(client: $0) }

			if let account = currentAccount
			{
				instanceService.instance(for: account)
				{ [weak self] instance in
					self?.currentInstance = instance
				}
			}
		}
	}

	var currentAccount: AuthorizedAccount?
	{
		didSet
		{
			accountSearchService = nil
			userPopUpButtonController.updateUserPopUpButton()

			if let account = currentAccount
			{
				let reauthAgent = accountsService.reauthorizationAgent(for: account)
				client = Client.create(for: account,
				                       keychainController: keychain.keychainController,
				                       reauthAgent: reauthAgent,
				                       urlSession: urlSession)
			}
			else
			{
				client = nil
			}
		}
	}

	func shouldChangeCurrentUser(to userUUID: UUID) -> Bool
	{
		guard !hasAttachments
		else
		{
			let response = NSAlert.confirmReuploadAttachmentsDialog().runModal()

			if response == .alertFirstButtonReturn
			{
				currentUser = userUUID
				attachmentsSubcontroller.discardAllAttachmentsAndUploadAgain()
				return true
			}
			else
			{
				return false
			}
		}

		return true
	}

	var currentInstance: Instance?
	{
		didSet
		{
			guard let instance = currentInstance, let client = self.client else { return }

			accountSearchService = AccountSearchService(client: client, activeInstance: instance)
		}
	}

	// MARK: View Lifecycle

	override var nibName: NSNib.Name?
	{
		return NSNib.Name("ShareViewController")
	}

	override func viewDidLoad()
	{
		super.viewDidLoad()

		setUp()
		loadInputItems()
	}

	private func setUp()
	{
		// we'll get here each time the share sheet is opened
		if logger == nil
		{
			LoggingSystem.bootstrap(LoggingOSLog.init)

			logger = Logger(subsystemType: self)
		}

		if Preferences.newWindowAccountMode == .pickFirstOne
		{
			currentAccount = accountsService.authorizedAccounts.first
		}

		let audienceItems = Visibility.allCases.map { $0.makeMenuItem() }
		let defaultAudience = Visibility.make(from: Preferences.defaultStatusAudience)

		audienceSelection = defaultAudience
		audiencePopupButton.menu?.setItems(audienceItems)

		attachmentsContainerView.isHidden = true

		textView.font = .systemFont(ofSize: 16)
		textView.insertDoubleNewLines = Preferences.insertDoubleNewLines

		observations.observePreference(\MastonautPreferences.insertDoubleNewLines)
		{
			[weak textView] preferences, _ in
			textView?.insertDoubleNewLines = preferences.insertDoubleNewLines
		}

		observations.observe(attachmentsSubcontroller, \AttachmentsSubcontroller.attachmentCount)
		{
			[unowned self] _, change in

			guard let oldCount = change.oldValue else { return }
			self.handleAttachmentCountsChanged(oldCount: oldCount)
		}

		userPopUpButtonController.updateUserPopUpButton()
	}

	private func loadInputItems()
	{
		guard
			let attachments = (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap({ $0.attachments ?? [] })
		else
		{
			return
		}

		textElementsToInsert.removeAll()
		let dispatchGroup = DispatchGroup()

		for attachment in attachments
		{
			if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String)
			{
				logger.debug2("attachment has URL")

				dispatchGroup.enter()
				loadURL(from: attachment) { dispatchGroup.leave() }
			}
			else if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String)
			{
				logger.debug2("attachment has image")

				dispatchGroup.enter()
				loadImage(from: attachment) { dispatchGroup.leave() }
			}
			else if attachment.hasItemConformingToTypeIdentifier(kUTTypePlainText as String)
			{
				logger.debug2("attachment has plain text")

				dispatchGroup.enter()
				loadString(from: attachment) { dispatchGroup.leave() }
			}
		}

		dispatchGroup.notify(queue: .main)
		{
			[weak self] in

			guard let self = self else { return }

			let joinedTextElements = self.textElementsToInsert.uniqueElements().joined(separator: " ")
			self.textView.insertAttributedString(NSAttributedString(string: joinedTextElements))
			self.postingService?.set(status: self.statusTextContent)
		}
	}

	private func loadURL(from attachment: NSItemProvider, completion: @escaping () -> Void)
	{
		let supportedUTIs = AttachmentUploader.supportedAttachmentTypes

		attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil)
		{ [weak self] object, _ in
			var url: URL?

			// as of macOS 13.0.1, both Safari and Maps encode the URL as data
			// https://github.com/chucker/Mastonaut/issues/57
			if let data = object as? Data, let urlString = String(data: data, encoding: .utf8)
			{
				url = URL(string: urlString)!
			}
			else if object is URL
			{}

			if url != nil, let self = self
			{
				if url!.isFileURL, let uti = url!.fileUTI, supportedUTIs.contains(uti as CFString)
				{
					self.attachmentsSubcontroller.addAttachments([url!])
				}
				else
				{
					self.textElementsToInsert.append(url!.absoluteString)
				}
			}

			completion()
		}
	}

	private func loadImage(from attachment: NSItemProvider, completion: @escaping () -> Void)
	{
		attachment.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil)
		{ [weak self] object, _ in
			if let image = object as? NSImage
			{
				self?.attachmentsSubcontroller.addAttachments([image])
			}
			completion()
		}
	}

	private func loadString(from attachment: NSItemProvider, completion: @escaping () -> Void)
	{
		attachment.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil)
		{ [weak self] object, _ in
			if let string = object as? String
			{
				self?.textElementsToInsert.insert(string, at: 0)
			}
			completion()
		}
	}

	@IBAction func send(_ sender: AnyObject?)
	{
		let attachments = attachmentsSubcontroller.attachments

		guard !attachmentsSubcontroller.hasAttachmentsPendingUpload
		else
		{
			showAlert(title: 🔠("Attention"),
			          message: 🔠("One or more attachments are still being uploaded. Please wait for them to complete uploading – or remove them – before submitting."))
			return
		}

		postingService?.post(visibility: audienceSelection,
		                     isSensitive: false,
		                     attachmentIds: attachments.compactMap { $0.attachment?.id },
		                     replyStatusId: nil,
		                     poll: nil)
		{
			[weak self] result in

			guard case .success = result
			else
			{
				// Show error
				return
			}

			DispatchQueue.main.async
			{
				self?.completeExtension()
			}
		}
	}

	@IBAction func cancel(_ sender: AnyObject?)
	{
		let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
		extensionContext!.cancelRequest(withError: cancelError)
	}

	@IBAction func didSelectAudience(_ sender: Any?)
	{
		if let audience = audiencePopupButton.selectedItem?.representedObject as? Visibility
		{
			audienceSelection = audience
		}
	}

	private func completeExtension()
	{
		let outputItem = NSExtensionItem()
		// Complete implementation by setting the appropriate value on the output item

		let outputItems = [outputItem]
		extensionContext!.completeRequest(returningItems: outputItems, completionHandler: nil)
	}

	private func handleAttachmentCountsChanged(oldCount: Int)
	{
		let newCount = attachmentsSubcontroller.attachmentCount

		if oldCount == 0, newCount > 0
		{
			attachmentsContainerView.isHidden = false
		}
		else if oldCount > 0, newCount == 0
		{
			attachmentsContainerView.isHidden = true
		}

		updateRemainingCountLabel()
	}
}

extension ShareViewController: NSTextViewDelegate
{
	func textDidChange(_ notification: Foundation.Notification)
	{
		postingService?.set(status: textView.string)
	}
}

extension ShareViewController: StatusComposerController
{
	func showAttachmentError(message: String)
	{
		let alert = NSAlert.makeAlert(style: .warning,
		                              title: 🔠("Error"),
		                              message: 🔠("compose.attachment.server", message),
		                              dialogMode: nil)

		alert.runModal()
	}
}
