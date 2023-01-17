//
//  StatusComposerWindowController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 04.01.19.
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
import MastodonKit

class StatusComposerWindowController: NSWindowController, UserPopUpButtonDisplaying
{
	@IBOutlet private unowned var authorAvatarView: NSImageView!
	@IBOutlet private unowned var textView: ComposerTextView!
	@IBOutlet private unowned var placeholderTextField: NSTextField!
	@IBOutlet private unowned var remainingCountLabel: NSTextField!
	@IBOutlet private unowned var contentWarningTextField: NSTextField!
	@IBOutlet private unowned var pollContainerView: NSView!

	@IBOutlet private unowned var contentWarningVisualEffectsView: NSVisualEffectView!

	@IBOutlet internal unowned var currentUserPopUpButton: NSPopUpButton!
	@IBOutlet private unowned var audiencePopupButton: NSPopUpButton!

	@IBOutlet private unowned var submitSegmentedControl: NSSegmentedControl!

	@IBOutlet private unowned var bottomControlsStackView: NSStackView!
	@IBOutlet private unowned var attachmentSegmentedControl: NSSegmentedControl!
	@IBOutlet private unowned var visibilitySegmentedControl: NSSegmentedControl!
	@IBOutlet private unowned var contentWarningSegmentedControl: NSSegmentedControl!
	@IBOutlet private unowned var pollSegmentedControl: NSSegmentedControl!

	@IBOutlet private unowned var informationButton: NSButton!
	@IBOutlet private unowned var informationPopover: NSPopover!
	@IBOutlet private unowned var informationPopoverLabel: NSTextField!

	@IBOutlet private unowned var submitStatusIndicator: NSProgressIndicator!

	@IBOutlet private unowned var replyStatusContainerView: NSView!
	@IBOutlet private unowned var replyStatusAvatarView: NSImageView!
	@IBOutlet private unowned var replyStatusAuthorNameLabel: NSTextField!
	@IBOutlet private unowned var replyStatusAuthorAccountLabel: NSTextField!
	@IBOutlet private unowned var replyStatusContentsLabel: AttributedLabel!

	@IBOutlet private unowned var contentWarningConstraint: NSLayoutConstraint!
	@IBOutlet private unowned var replyStatusConstraint: NSLayoutConstraint!
	@IBOutlet private unowned var bottomDrawerConstraint: NSLayoutConstraint!
	@IBOutlet private unowned var attachmentsConstraint: NSLayoutConstraint!

	@IBOutlet private unowned var attachmentsSubcontroller: AttachmentsSubcontroller!

	@IBOutlet private unowned var emojiPickerPanelController: CustomEmojiPanelController!
	@IBOutlet private unowned var emojiPickerPopover: NSPopover!
	@IBOutlet private unowned var emojiSegmentedControl: NSSegmentedControl!

	private unowned let accountsService = AppDelegate.shared.accountsService
	private unowned let instanceService = AppDelegate.shared.instanceService

	private let pollViewController = ComposerPollViewController()

	private var statusCharacterLimit = 500
	private let resourcesFetcher = ResourcesFetcher(urlSession: AppDelegate.shared.resourcesUrlSession)

	private lazy var userPopUpButtonController = UserPopUpButtonSubcontroller(display: self)

	private static let authorLabelAttributes: [NSAttributedString.Key: AnyObject] = [
		.foregroundColor: NSColor.labelColor, .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
	]

	private static let statusLabelAttributes: [NSAttributedString.Key: AnyObject] = [
		.foregroundColor: NSColor.labelColor, .font: NSFont.labelFont(ofSize: 13)
	]

	private static let statusLabelLinkAttributes: [NSAttributedString.Key: AnyObject] = [
		.foregroundColor: NSColor.safeControlTintColor,
		.font: NSFont.systemFont(ofSize: 13, weight: .medium),
		.underlineStyle: NSNumber(value: 1)
	]

	private lazy var fileDropFilteringOptions: [NSPasteboard.ReadingOptionKey: Any]? =
	{
		[.urlReadingContentsConformToTypes: AttachmentUploader.supportedAttachmentTypes]
	}()

	private var hasValidTextContents: Bool { return (1 ... statusCharacterLimit).contains(totalCharacterCount) }
	private var hasAttachments: Bool { return !attachmentsSubcontroller.attachments.isEmpty }
	private var hasActiveUploadTasks: Bool { return attachmentsSubcontroller.attachmentUploader.hasActiveTasks }
	private var hasActiveSubmitTask: Bool { return postingService?.isSubmiting == true }
	private var hasActiveResolverTask: Bool { return resolverService?.isResolving == true }
	private var hasActiveTasks: Bool { return hasActiveSubmitTask || hasActiveUploadTasks || hasActiveResolverTask }
	private var hasPoll: Bool { return pollSegmentedControl.isSelected(forSegment: 0) }

	private var isDirty: Bool
	{
		return totalCharacterCount > 0
			|| hasAttachments
			|| hasActiveTasks
			|| pollViewController.isDirty
			|| replyStatus != nil
	}

	private var hasValidPollConfiguration: Bool
	{
		return !hasPoll || (!hasAttachments && pollViewController.allOptionsAreValid)
	}

	private var canSubmitStatus: Bool
	{
		return (hasValidTextContents || hasAttachments) && hasValidPollConfiguration && !hasActiveTasks && client != nil
	}

	private var statusTextContent: String
	{
		return textView.attributedString().strippingEmojiAttachments(insertJoinersBetweenEmojis: Preferences.insertJoinersBetweenEmojis)
	}

	private var contentWarningTextContent: String?
	{
		return contentWarningEnabled ? contentWarningTextField.stringValue : nil
	}

	private var totalCharacterCount: Int
	{
		return postingService?.characterCount ?? 0
	}

	private var bottomDrawerMode: BottomDrawerMode = []
	{
		didSet
		{
			updateBottomDrawerConstraint()
		}
	}

	private var audienceSelection: Visibility = Visibility.make(from: Preferences.defaultStatusAudience)
	private var resolverServiceObservations: [NSKeyValueObservation] = []
	private var postingServiceObservations: [NSKeyValueObservation] = []
	private var observations: [NSKeyValueObservation] = []
	private var currentAccountObservations: [NSKeyValueObservation] = []
	private var currentClientEmoji: [CacheableEmoji]?
	{
		willSet { willChangeValue(for: \.hasLoadedClientEmoji) }
		didSet
		{
			didChangeValue(for: \.hasLoadedClientEmoji)
			currentClientEmoji.map { emojiPickerPanelController.setEmoji($0) }
		}
	}

	@objc var hasLoadedClientEmoji: ObjCBool { return ObjCBool(booleanLiteral: currentClientEmoji != nil) }

	private var resolverService: ResolverService?
	{
		didSet
		{
			resolverServiceObservations.removeAll()

			guard let service = resolverService else { return }

			resolverServiceObservations.observe(service, \.resolverFuture)
			{ [weak self] _, _ in
				DispatchQueue.main.async
				{
					self?.updateSubmitEnabled()
					self?.submitStatusIndicator.setAnimating(self?.hasActiveTasks ?? false)
				}
			}
		}
	}

	private var accountSearchService: AccountSearchService?
	{
		didSet
		{
			textView.suggestionsProvider = accountSearchService
		}
	}

	private var postingService: PostingService?
	{
		didSet
		{
			postingServiceObservations.removeAll()

			guard let service = postingService else { return }

			service.set(status: statusTextContent)
			service.set(contentWarning: contentWarningTextContent)

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

	private var currentInstance: Instance?
	{
		didSet
		{
			guard let instance = currentInstance, let client = client else { return }

			accountSearchService = AccountSearchService(client: client, activeInstance: instance)
		}
	}

	private var client: ClientType?
	{
		didSet
		{
			attachmentsSubcontroller.client = client

			postingService = client.map { PostingService(client: $0) }
			resolverService = client.map { ResolverService(client: $0) }
			accountSearchService = nil
			currentInstance = nil

			if let account = currentAccount
			{
				instanceService.instance(for: account)
				{
					[weak self] instance in

					self?.currentInstance = instance
				}
			}

			if let client = client, oldValue != nil, client.baseURL != oldValue!.baseURL, let replyStatus = replyStatus
			{
				resolverService?.resolveStatus(uri: replyStatus.resolvableURI)
				{
					[weak self] result in

					DispatchQueue.main.async
					{
						guard let self = self else { return }

						switch (result, self.replyStatusSenderWindowController)
						{
						case (.success(let status), .some(let windowController)):
							self.setupAsReply(to: status,
							                  using: self.currentAccount,
							                  senderWindowController: windowController)

						case (.failure(let error), _):
							NSLog("Failed resolving status: \(error)")
							fallthrough

						default:
							self.dismissReplyStatus()
						}
					}
				}
			}

			if let client = client, oldValue?.baseURL != client.baseURL
			{
				currentClientEmoji = nil
				fetchInstanceEmoji(using: client)
			}
		}
	}

	private weak var replyStatusSenderWindowController: TimelinesWindowController?
	private var replyStatus: Status?
	{
		didSet
		{
			if replyStatus != nil
			{
				replyStatusContainerView.layoutSubtreeIfNeeded()
				replyStatusConstraint.animator().constant = replyStatusContainerView.frame.height + 2
			}
			else
			{
				let heightDelta = replyStatusConstraint.constant
				replyStatusConstraint.animator().constant = 0

				if var frame = window?.frame
				{
					frame.size.height -= heightDelta
					frame.origin.y += heightDelta
					window?.animator().setFrame(frame, display: false)
				}
			}
		}
	}

	private var mediaIsVisible: Bool = true
	{
		didSet
		{
			visibilitySegmentedControl.setSelected(!mediaIsVisible, forSegment: 0)
			visibilitySegmentedControl.setImage(mediaIsVisible ? #imageLiteral(resourceName: "eye_open") : #imageLiteral(resourceName: "eye_blocked"), forSegment: 0)
		}
	}

	private var isReceivingDrag: Bool = false
	{
		didSet
		{
			if isReceivingDrag, !bottomDrawerMode.contains(.attachment)
			{
				bottomDrawerMode.insert(.attachment)
			}
			else if !isReceivingDrag, bottomDrawerMode.contains(.attachment), !hasAttachments
			{
				bottomDrawerMode.subtract(.attachment)
			}

			attachmentsSubcontroller.showProposedAttachmentItem = isReceivingDrag
		}
	}

	override var windowNibName: NSNib.Name?
	{
		return "StatusComposerWindowController"
	}

	internal var currentUser: UUID?
	{
		get { return currentAccount?.uuid }
		set { currentAccount = newValue.flatMap { accountsService.account(with: $0) } }
	}

	var currentAccount: AuthorizedAccount?
	{
		didSet
		{
			currentAccountObservations.removeAll()

			if let currentAccount = currentAccount
			{
				let accountUUID = currentAccount.uuid
				client = Client.create(for: currentAccount)
				authorAvatarView.image = #imageLiteral(resourceName: "missing.png")

				if let accountPreferences = currentAccount.accountPreferences
				{
					currentAccountObservations.observe(accountPreferences, \.customTootLengthLimit, sendInitial: true)
					{
						[weak self] accountPreferences, _ in

						self?.statusCharacterLimit = accountPreferences.customTootLengthLimit?.intValue ?? 500
						self?.updateRemainingCountLabel()
					}
				}

				AppDelegate.shared.avatarImageCache.fetchImage(account: currentAccount)
				{ [weak self] result in
					switch result
					{
					case .inCache(let image):
						assert(Thread.isMainThread)
						self?.authorAvatarView.image = image
					case .loaded(let image):
						self?.applyAuthorImageIfNotReused(image, originalAccountUUID: accountUUID)
					case .noImage:
						self?.applyAuthorImageIfNotReused(nil, originalAccountUUID: accountUUID)
					}
				}
			}
			else
			{
				authorAvatarView.image = #imageLiteral(resourceName: "missing")
				client = nil
			}

			userPopUpButtonController.updateUserPopUpButton()

			if window?.isKeyWindow == true
			{
				AppDelegate.shared.updateAccountsMenu()
			}
		}
	}

	private var contentWarningEnabled: Bool = true
	{
		didSet
		{
			contentWarningConstraint.animator().constant = contentWarningEnabled ? 40 : 0
			contentWarningTextField.isEnabled = contentWarningEnabled

			if contentWarningEnabled
			{
				window?.makeFirstResponder(contentWarningTextField)
			}
			else
			{
				window?.makeFirstResponder(textView)
			}

			postingService?.set(contentWarning: contentWarningTextContent)
		}
	}

	private var pollEnabled: Bool
	{
		get
		{
			return pollSegmentedControl.isSelected(forSegment: 0)
		}

		set(enable)
		{
			pollSegmentedControl.setSelected(enable, forSegment: 0)

			if enable
			{
				bottomDrawerMode.insert(.poll)
			}
			else
			{
				pollViewController.reset()
				bottomDrawerMode.subtract(.poll)
			}
		}
	}

	private lazy var openPanel: NSOpenPanel = {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = true
		panel.allowedFileTypes = AttachmentUploader.supportedAttachmentTypes.map { $0 as String }
		panel.message = 🔠("Select one or more files to upload and attach to your status.")
		panel.prompt = 🔠("Attach")
		return panel
	}()

	override func awakeFromNib()
	{
		super.awakeFromNib()

		window?.registerForDraggedTypes([.fileURL, .png])

		replyStatusContentsLabel.linkTextAttributes = StatusComposerWindowController.statusLabelLinkAttributes
		visibilitySegmentedControl.isHidden = true

		collapseAllDrawers()
		updateRemainingCountLabel()

		let audienceItems = Visibility.allCases.map { $0.makeMenuItem() }
		let defaultAudience = Visibility.make(from: Preferences.defaultStatusAudience)

		audienceSelection = defaultAudience
		audiencePopupButton.menu?.setItems(audienceItems)

		audiencePopupButton.select(audienceItems.first(where: { $0.representedObject ?== defaultAudience }))
		observations.observePreference(\MastonautPreferences.defaultStatusAudience)
		{
			[weak self, weak audiencePopupButton] preferences, _ in

			let defaultAudience = Visibility.make(from: preferences.defaultStatusAudience)
			self?.audienceSelection = defaultAudience
			audiencePopupButton?.select(audienceItems.first(where: { $0.representedObject ?== defaultAudience }))
		}

		textView.font = placeholderTextField.font
		textView.insertDoubleNewLines = Preferences.insertDoubleNewLines
		textView.imagesProvider = resourcesFetcher

		if #available(OSX 10.14, *) {}
		else
		{
			textView.textContainerInset = NSSize(width: 72, height: 8)
		}

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

		if #available(OSX 10.14, *)
		{
			contentWarningVisualEffectsView.state = .followsWindowActiveState
			contentWarningVisualEffectsView.material = .contentBackground
		}

		currentUserPopUpButton.widthAnchor.constraint(lessThanOrEqualToConstant: 140).isActive = true

		pollContainerView.addSubview(pollViewController.view)
		NSLayoutConstraint.activate(NSLayoutConstraint.constraintsEmbedding(view: pollViewController.view,
		                                                                    in: pollContainerView,
		                                                                    inset: NSSize(width: 12, height: 12)))

		observations.observe(pollViewController.view, \.frame)
		{
			[weak self] _, _ in self?.updateBottomDrawerConstraint()
		}

		observations.observe(pollViewController, \.allOptionsAreValid)
		{
			[weak self] _, _ in self?.updateSubmitEnabled()
		}

		observations.observe(pollViewController, \.isDirty)
		{
			[weak self] _, _ in self?.updateSubmitEnabled()
		}

		textView.nextKeyView = pollViewController.initialKeyView
		pollViewController.nextKeyView = contentWarningTextField
	}

	func shouldChangeCurrentUser(to userUUID: UUID) -> Bool
	{
		guard !hasAttachments
		else
		{
			NSAlert.confirmReuploadAttachmentsDialog().beginSheetModal(for: window!)
			{
				response in

				if response == .alertFirstButtonReturn
				{
					self.currentUser = userUUID
					self.attachmentsSubcontroller.discardAllAttachmentsAndUploadAgain()
				}
			}

			return false
		}

		return true
	}

	func windowDidResignMain(_ notification: Foundation.Notification)
	{
		textView.dismissSuggestionsWindow()
	}

	private func handleAttachmentCountsChanged(oldCount: Int)
	{
		let newCount = attachmentsSubcontroller.attachmentCount

		if oldCount == 0, newCount > 0
		{
			bottomDrawerMode.insert(.attachment)
			visibilitySegmentedControl.setEnabled(true, forSegment: 0)
			bottomControlsStackView.setArrangedSubview(visibilitySegmentedControl, hidden: false, animated: true)
		}
		else if oldCount > 0, newCount == 0
		{
			bottomDrawerMode.subtract(.attachment)
			visibilitySegmentedControl.setEnabled(false, forSegment: 0)
			bottomControlsStackView.setArrangedSubview(visibilitySegmentedControl, hidden: true, animated: true)
		}

		updateRemainingCountLabel()
	}

	private func collapseAllDrawers()
	{
		guard let window = window else { return }

		let constraintsToCollapse = [
			contentWarningConstraint,
			bottomDrawerConstraint,
			replyStatusConstraint
		]

		let totalCollapsedHeight = constraintsToCollapse.reduce(0) { $0 + $1!.constant }

		constraintsToCollapse.forEach { $0!.constant = 0 }
		// This is done separatelly because collapsing this constraint doesn't affect the window height
		attachmentsConstraint.constant = 0

		window.setFrame(window.frame.insetBy(dx: 0, dy: totalCollapsedHeight / 2), display: true)
	}

	func setupAsReply(to status: Status,
	                  using account: AuthorizedAccount?,
	                  senderWindowController: TimelinesWindowController)
	{
		guard confirmDiscardChangesIfNeeded(completion: { shouldDiscard in
			if shouldDiscard
			{
				self.textView.string = ""
				self.setupAsReply(to: status, using: account, senderWindowController: senderWindowController)
			}
		}) else { return }

		currentAccount = account

		let replyStatus = status.reblog ?? status
		let mentionSet = NSMutableOrderedSet(array: replyStatus.mentions.map { $0.acct })

		if mentionSet.contains(replyStatus.account.acct) == false
		{
			mentionSet.insert(replyStatus.account.acct, at: 0)
		}

		if let currentUsername = currentAccount?.username
		{
			mentionSet.remove(currentUsername)
		}

		let newText = mentionSet.map { "@\($0) " }.joined()

		attachmentsSubcontroller.reset()
		textView.string = newText

		if mentionSet.count > 0
		{
			let newTextLength = (newText as NSString).length
			let replyURILength = ("@\(mentionSet.firstObject as! String) " as NSString).length
			textView.setSelectedRange(NSRange(location: replyURILength, length: newTextLength - replyURILength))
		}

		if let instance = currentInstance
		{
			replyStatusAuthorAccountLabel.stringValue = replyStatus.account.uri(in: instance)
		}
		else
		{
			replyStatusAuthorAccountLabel.stringValue = replyStatus.account.acct
		}

		replyStatusAuthorNameLabel.set(stringValue: replyStatus.authorName,
		                               applyingAttributes: StatusComposerWindowController.authorLabelAttributes,
		                               applyingEmojis: replyStatus.account.cacheableEmojis)

		replyStatusContentsLabel.linkHandler = self
		replyStatusContentsLabel.set(attributedStringValue: replyStatus.attributedContent,
		                             applyingAttributes: StatusComposerWindowController.statusLabelAttributes,
		                             applyingEmojis: replyStatus.cacheableEmojis)

		replyStatusAvatarView.image = #imageLiteral(resourceName: "missing")

		setContentWarning(status.spoilerText)

		if contentWarningEnabled
		{
			window?.makeFirstResponder(textView)
		}

		setAudienceSelection(visibility: status.visibility)
		updateRemainingCountLabel()

		// Do this last so that the setter gets to calculate the needed height for the constraint.
		self.replyStatus = replyStatus
		replyStatusSenderWindowController = senderWindowController

		let localStatusID = replyStatus.id
		AppDelegate.shared.avatarImageCache.fetchImage(account: replyStatus.account)
		{ [weak self] result in
			switch result
			{
			case .inCache(let image):
				assert(Thread.isMainThread)
				self?.replyStatusAvatarView.image = image
			case .loaded(let image):
				self?.applyAvatarImageIfNotReused(image, originatingStatusID: localStatusID)
			case .noImage:
				self?.applyAvatarImageIfNotReused(nil, originatingStatusID: localStatusID)
			}
		}
	}

	func setupAsMention(handle: String, using account: AuthorizedAccount?, directMessage: Bool)
	{
		guard confirmDiscardChangesIfNeeded(completion: { shouldDiscard in
			if shouldDiscard
			{
				self.textView.string = ""
				self.setupAsMention(handle: handle, using: account, directMessage: directMessage)
			}
		}) else { return }

		currentAccount = account

		postingService?.reset()
		attachmentsSubcontroller.reset()
		setContentWarning("")
		setAudienceSelection(visibility: directMessage ? .direct
			: Visibility.make(from: Preferences.defaultStatusAudience))

		let newStatus = "\(handle) "
		postingService?.set(status: newStatus)
		textView.string = newStatus

		updateSubmitEnabled()
		updateRemainingCountLabel()
	}

	func setUpAsRedraft(of status: Status, using account: AuthorizedAccount?)
	{
		guard status.reblog == nil else { return }

		guard confirmDiscardChangesIfNeeded(completion: { shouldDiscard in
			if shouldDiscard
			{
				self.textView.string = ""
				self.setUpAsRedraft(of: status, using: account)
			}
		}) else { return }

		currentAccount = account

		attachmentsSubcontroller.reset()
		textView.string = status.fullAttributedContent.replacingMentionsWithURIs(mentions: status.mentions)
		postingService?.set(status: status.fullAttributedContent.string)

		DispatchQueue.main.async
		{
			self.textView.replaceShortcodesWithEmojiIfPossible()
		}

		setContentWarning(status.spoilerText)
		setAudienceSelection(visibility: status.visibility)

		updateSubmitEnabled()
		updateRemainingCountLabel()

		if let poll = status.poll
		{
			pollEnabled = true
			pollViewController.optionTitles = poll.options.map { $0.title }
		}

		guard !status.mediaAttachments.isEmpty else { return }

		let uploads = attachmentsSubcontroller.addAttachments(status.mediaAttachments)
		let resourceFetcher = resourcesFetcher

		for upload in uploads
		{
			guard let url = upload.attachment?.parsedPreviewUrl else { continue }
			resourceFetcher.fetchImage(with: url)
			{
				[weak self] result in

				guard case .success(let image) = result else { return }

				DispatchQueue.main.async
				{
					self?.attachmentsSubcontroller.update(thumbnail: image, for: upload)
				}
			}
		}
	}

	private func confirmDiscardChangesIfNeeded(completion: @escaping (Bool) -> Void) -> Bool
	{
		guard statusTextContent.isEmpty
		else
		{
			showAlert(style: .warning,
			          title: 🔠("Discard current draft?"),
			          message: 🔠("Composing a reply now will discard your currently drafted toot, including attachments. Do you wish to proceed?"),
			          dialogMode: .discardKeepEditing)
			{
				response in completion(response == .alertFirstButtonReturn)
			}
			return false
		}

		return true
	}

	private func setAudienceSelection(visibility: Visibility)
	{
		audienceSelection = visibility
		if let item = audiencePopupButton.menu?.items.first(where: { $0.representedObject ?== visibility })
		{
			audiencePopupButton.select(item)
		}
	}

	private func setContentWarning(_ contentWarning: String)
	{
		contentWarningSegmentedControl.setSelected(!contentWarning.isEmpty, forSegment: 0)
		contentWarningTextField.stringValue = contentWarning
		postingService?.set(contentWarning: contentWarning)
		contentWarningEnabled = !contentWarning.isEmpty
	}

	private func applyAvatarImageIfNotReused(_ image: NSImage?, originatingStatusID: String)
	{
		DispatchQueue.main.async
		{
			[weak self] in

			// Make sure that the status view hasn't been reused since this fetch was dispatched.
			guard self?.replyStatus?.id == originatingStatusID
			else
			{
				return
			}

			self?.replyStatusAvatarView.image = image ?? #imageLiteral(resourceName: "missing")
		}
	}

	private func applyAuthorImageIfNotReused(_ image: NSImage?, originalAccountUUID: UUID)
	{
		DispatchQueue.main.async
		{
			[weak self] in

			// Make sure that the composer view hasn't been reused since this fetch was dispatched.
			guard self?.currentUser == originalAccountUUID
			else
			{
				return
			}

			self?.authorAvatarView.image = image ?? #imageLiteral(resourceName: "missing")
		}
	}

	private func updateRemainingCountLabel()
	{
		placeholderTextField.isHidden = !statusTextContent.isEmpty

		let remainingCount = statusCharacterLimit - totalCharacterCount
		remainingCountLabel.integerValue = remainingCount
		remainingCountLabel.textColor = .labelColor(for: remainingCount)

		updateSubmitEnabled()
	}

	func updateSubmitEnabled()
	{
		submitSegmentedControl.isEnabled = canSubmitStatus
		setDocumentEdited(isDirty)
	}

	private func validateAndSendStatus()
	{
		guard canSubmitStatus
		else
		{
			return
		}

		let attachments = attachmentsSubcontroller.attachments

		guard !attachmentsSubcontroller.hasAttachmentsPendingUpload
		else
		{
			showAlert(title: 🔠("Attention"),
			          message: 🔠("One or more attachments are still being uploaded. Please wait for them to complete uploading – or remove them – before submitting."))
			return
		}

		var poll: PollPayload?

		if hasPoll, pollViewController.allOptionsAreValid
		{
			poll = PollPayload(options: pollViewController.optionTitles,
			                   expiration: pollViewController.pollDuration,
			                   multipleChoice: pollViewController.multipleChoice)
		}

		postingService?.post(visibility: audienceSelection,
		                     isSensitive: visibilitySegmentedControl.isSelected(forSegment: 0),
		                     attachmentIds: attachments.compactMap { $0.attachment?.id },
		                     replyStatusId: replyStatus?.id,
		                     poll: poll)
		{
			[weak self] result in

			guard let self = self else { return }

			switch result
			{
			case .success:
				self.reset()

			case .failure(let error):
				self.updateSubmitEnabled()
				self.window?.windowController?.displayError(NetworkError(error))
			}
		}

		updateSubmitEnabled()
	}

	private func fetchInstanceEmoji(using client: ClientType)
	{
		guard let instance = client.parsedBaseUrl?.host
		else
		{
			currentClientEmoji = nil
			return
		}

		client.run(Instances.customEmojis())
		{
			[weak self] result in

			DispatchQueue.main.async
			{
				guard let self = self, case .success(let emoji, _) = result else { return }

				self.currentClientEmoji = emoji.cacheable(instance: instance)
					.sorted()
					.filter { $0.visibleInPicker }
			}
		}
	}

	private func reset()
	{
		replyStatus = nil
		replyStatusSenderWindowController = nil
		setAudienceSelection(visibility: Visibility.make(from: Preferences.defaultStatusAudience))
		textView.string = ""
		contentWarningTextField.stringValue = ""
		contentWarningEnabled = false
		contentWarningSegmentedControl.setSelected(false, forSegment: 0)
		postingService?.reset()

		pollEnabled = false

		// Bug: These controls get disabled when a modal alert is displayed on a sheet, but never get reactivated.
		// So we re-enable them here just in case.
		currentUserPopUpButton.isEnabled = true
		audiencePopupButton.isEnabled = true
		informationButton.isEnabled = true

		updateRemainingCountLabel()
		attachmentsSubcontroller.reset()

		window?.orderOut(nil)
	}

	private func dismissReplyStatus()
	{
		replyStatus = nil
		textView.string = ""
		contentWarningTextField.stringValue = ""
		contentWarningEnabled = false
		contentWarningSegmentedControl.setSelected(false, forSegment: 0)
		updateRemainingCountLabel()
	}

	private func updateBottomDrawerConstraint()
	{
		var bottomDrawerConstant: CGFloat = 0
		var attachmentsConstant: CGFloat = 0

		if bottomDrawerMode.contains(.attachment)
		{
			bottomDrawerConstant += 82
			attachmentsConstant += 82
		}

		if bottomDrawerMode.contains(.poll)
		{
			bottomDrawerConstant += pollContainerView.frame.height + 2
			attachmentsConstant += 2
		}

		let oldBottomDrawerConstant = bottomDrawerConstraint.constant

		NSAnimationContext.runAnimationGroup
		{
			context in

			context.duration = 0.15
			context.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

			self.bottomDrawerConstraint.animator().constant = bottomDrawerConstant
			self.attachmentsConstraint.animator().constant = attachmentsConstant

			if oldBottomDrawerConstant > bottomDrawerConstant, let window = self.window
			{
				var frame = window.frame
				let height = max(window.minSize.height, frame.height - (oldBottomDrawerConstant - bottomDrawerConstant))
				frame.origin.y += oldBottomDrawerConstant - bottomDrawerConstant
				frame.size.height = height
				window.animator().setFrame(frame, display: true)
			}
		}
	}

	private struct BottomDrawerMode: OptionSet
	{
		let rawValue: Int8

		static let attachment = BottomDrawerMode(rawValue: 1 << 0)
		static let poll = BottomDrawerMode(rawValue: 1 << 1)
	}
}

extension StatusComposerWindowController: NSWindowDelegate
{
	func windowShouldClose(_ sender: NSWindow) -> Bool
	{
		guard !isDirty
		else
		{
			showAlert(title: 🔠("Discard current draft?"),
			          message: 🔠("Closing the composer now will discard your currently drafted toot, including attachments. Do you wish to proceed?"),
			          dialogMode: .discardKeepEditing)
			{
				response in

				if response == .alertFirstButtonReturn
				{
					self.reset()
				}
			}
			return false
		}

		return true
	}
}

extension StatusComposerWindowController: AttributedLabelLinkHandler
{
	func handle(linkURL: URL)
	{
		replyStatusSenderWindowController?.handle(linkURL: linkURL, knownTags: replyStatus?.tags)
	}
}

extension StatusComposerWindowController: NSDraggingDestination
{
	func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
	{
		guard
			sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self, NSImage.self],
			                                        options: fileDropFilteringOptions)
		else
		{
			return NSDragOperation()
		}

		isReceivingDrag = true

		return .copy
	}

	func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation
	{
		return .copy
	}

	func draggingExited(_ sender: NSDraggingInfo?)
	{
		isReceivingDrag = false
	}

	func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool
	{
		return sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self, NSImage.self],
		                                               options: fileDropFilteringOptions)
	}

	func performDragOperation(_ sender: NSDraggingInfo) -> Bool
	{
		if let attachmentUrls = sender.draggedFileUrls, !attachmentUrls.isEmpty
		{
			attachmentsSubcontroller.addAttachments(attachmentUrls)
			return true
		}
		else if let attachmentImages = sender.draggedImages, !attachmentImages.isEmpty
		{
			attachmentsSubcontroller.addAttachments(attachmentImages)
			return true
		}

		return false
	}

	func concludeDragOperation(_ sender: NSDraggingInfo?)
	{
		isReceivingDrag = false
	}
}

extension StatusComposerWindowController: NSTextFieldDelegate
{
	func controlTextDidChange(_ notification: Foundation.Notification)
	{
		if (notification.object as? NSTextField) === contentWarningTextField
		{
			postingService?.set(contentWarning: contentWarningTextContent)
		}
	}
}

extension StatusComposerWindowController: NSTextViewDelegate
{
	func textDidChange(_ notification: Foundation.Notification)
	{
		postingService?.set(status: statusTextContent)
	}
}

extension StatusComposerWindowController: BaseComposerTextViewPasteDelegate
{
	func readablePasteboardTypes(for controlTextView: BaseComposerTextView,
	                             proposedTypes: [NSPasteboard.PasteboardType]) -> [NSPasteboard.PasteboardType]
	{
		return proposedTypes + [.fileURL, .png, .tiff]
	}

	func readFromPasteboard(for controlTextView: BaseComposerTextView) -> Bool
	{
		return attachmentsSubcontroller?.addAttachments(pasteboard: NSPasteboard.general) ?? false
	}
}

extension StatusComposerWindowController: AccountsMenuProvider
{
	private var accounts: [AuthorizedAccount]
	{
		return accountsService.authorizedAccounts
	}

	var accountsMenuItems: [NSMenuItem]
	{
		return accounts.makeMenuItems(currentUser: currentAccount?.uuid,
		                              action: #selector(UserPopUpButtonSubcontroller.selectAccount(_:)),
		                              target: userPopUpButtonController,
		                              emojiContainer: nil,
		                              setKeyEquivalents: true).menuItems
	}
}

extension StatusComposerWindowController
{
	@IBAction func sendStatus(_ sender: Any?)
	{
		validateAndSendStatus()
	}

	@IBAction func didSelectMediaVisibility(_ sender: Any?)
	{
		mediaIsVisible = !visibilitySegmentedControl.isSelected(forSegment: 0)
	}

	@IBAction func didSelectContentWarning(_ sender: Any?)
	{
		contentWarningEnabled = contentWarningSegmentedControl.isSelected(forSegment: 0)
	}

	@IBAction func didSelectPoll(_ sender: Any?)
	{
		if pollSegmentedControl.isSelected(forSegment: 0)
		{
			bottomDrawerMode.insert(.poll)
		}
		else
		{
			bottomDrawerMode.subtract(.poll)
		}

		updateSubmitEnabled()
	}

	@IBAction func didSelectAudience(_ sender: Any?)
	{
		if let audience = audiencePopupButton.selectedItem?.representedObject as? Visibility
		{
			audienceSelection = audience
		}
	}

	@IBAction func showEmojiPickerPopover(_ sender: Any?)
	{
		let control = emojiSegmentedControl!
		emojiPickerPopover.show(relativeTo: control.bounds, of: control, preferredEdge: .maxX)
	}

	@IBAction func showAttachmentPickerSheet(_ sender: Any?)
	{
		guard let window = window
		else
		{
			return
		}

		openPanel.beginSheetModal(for: window)
		{
			[weak self] response in

			guard response == .OK, let urls = self?.openPanel.urls
			else
			{
				return
			}

			DispatchQueue.main.async { self?.attachmentsSubcontroller.addAttachments(urls) }
		}
	}

	@IBAction func showAudienceInfo(_ sender: Any?)
	{
		let informationString: String

		switch audienceSelection
		{
		case .public:
			informationString = 🔠("Post to public timelines.")

		case .unlisted:
			informationString = 🔠("Do not post to public timelines.")

		case .private:
			informationString = 🔠("Post to followers only. Attention: If your account is not locked, anyone can follow you to view your follower-only posts.")

		case .direct:
			informationString = 🔠("This toot will only be sent to the mentioned users.")
		}

		informationPopoverLabel.stringValue = informationString
		informationPopover.show(relativeTo: informationButton.bounds, of: informationButton, preferredEdge: .minY)
	}

	@IBAction func clickedDismissReplyButton(_ sender: Any?)
	{
		dismissReplyStatus()
	}
}

extension StatusComposerWindowController: CustomEmojiSelectionHandler
{
	func customEmojiPanel(_ emojiPanelController: CustomEmojiPanelController, didSelectEmoji emojiAdapter: EmojiAdapter)
	{
		emojiPickerPopover.close()
		let emoji = emojiAdapter.emoji
		let emojiString = ":\(emoji.shortcode):".applyingEmojiAttachments([emoji],
		                                                                  font: textView.font,
		                                                                  containerView: textView)
		textView.insertAttributedString(emojiString)
	}
}

extension StatusComposerWindowController: ComposerTextViewEmojiProvider
{
	func composerTextView(_ textView: ComposerTextView, emojiForShortcode shortcode: String) -> NSAttributedString?
	{
		guard let emoji = currentClientEmoji?.first(where: { $0.shortcode == shortcode }) else { return nil }
		return (":\(shortcode):" as NSString).applyingEmojiAttachments([emoji],
		                                                               font: placeholderTextField.font,
		                                                               containerView: textView)
	}
}

extension StatusComposerWindowController: StatusComposerController
{
	func showAttachmentError(message: String)
	{
		showAlert(style: .warning, title: 🔠("Error"), message: message)
	}
}
