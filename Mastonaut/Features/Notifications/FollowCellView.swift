//
//  FollowCellView.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 26.01.19.
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

class FollowCellView: MastonautTableCellView, NotificationDisplaying
{
	@IBOutlet private unowned var interactionIcon: NSImageView!
	@IBOutlet private unowned var interactionLabel: NSButton!
	@IBOutlet private unowned var agentAvatarButton: NSButton!
	@IBOutlet private unowned var userAccountLabel: NSTextField!
	@IBOutlet private unowned var userBioLabel: AttributedLabel!
	@IBOutlet private unowned var timeLabel: NSTextField!
	@IBOutlet var followRequestResponsesStackView: NSStackView!

	private unowned var interactionHandler: NotificationInteractionHandling?

	private var agentAccount: Account?
	private var displayedNotificationTags: [Tag]?

	private var notification: MastodonNotification?

	var displayedNotificationId: String?

	// This cell never displays statuses
	let displayedStatusId: String? = nil

	private func fontService() -> FontService
	{
		return FontService(font: MastonautPreferences.instance.statusFont)
	}

	override func awakeFromNib()
	{
		super.awakeFromNib()

		timeLabel.formatter = RelativeDateFormatter.shared

		fontObserver = MastonautPreferences.instance.observe(\.statusFont, options: .new)
		{
			[weak self] _, _ in
			self?.updateFont()
		}
	}

	private var fontObserver: NSKeyValueObservation?

	deinit
	{
		fontObserver?.invalidate()
	}

	func updateFont()
	{
		userBioLabel.linkTextAttributes = fontService().userBioLinkAttributes()

		redraw()
	}

	override var backgroundStyle: NSView.BackgroundStyle
	{
		didSet
		{
			let emphasized = backgroundStyle == .emphasized
			userBioLabel.isEmphasized = emphasized

			if #available(OSX 10.14, *) {} else
			{
				let effectiveColor: NSColor = emphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
				userAccountLabel.textColor = effectiveColor
				timeLabel.textColor = effectiveColor
			}
		}
	}

	func set(displayedNotification notification: MastodonNotification,
	         attachmentPresenter: AttachmentPresenting,
	         interactionHandler: NotificationInteractionHandling,
	         activeInstance: Instance)
	{
		self.notification = notification

		displayedNotificationId = notification.id
		self.interactionHandler = interactionHandler
		agentAccount = notification.account

		displayedNotificationTags = notification.status?.tags

		userBioLabel.linkHandler = self

		switch notification.type
		{
		case .follow:
			followRequestResponsesStackView.isHidden = true
		case .follow_request:
			followRequestResponsesStackView.isHidden = false
		default:
			break
		}

		redraw()

		userBioLabel.isHidden = userBioLabel.attributedStringValue.length == 0
		userBioLabel.selectableAfterFirstClick = true

		userAccountLabel.stringValue = notification.account.uri(in: activeInstance)
		timeLabel.objectValue = notification.createdAt
		timeLabel.toolTip = DateFormatter.longDateFormatter.string(from: notification.createdAt)

		let localNotificationID = notification.id
		AppDelegate.shared.avatarImageCache.fetchImage(account: notification.account)
		{ [weak self] result in
			switch result
			{
			case .inCache(let avatarImage):
				assert(Thread.isMainThread)
				self?.agentAvatarButton.image = avatarImage
			case .loaded(let avatarImage):
				self?.applyAgentImageIfNotReused(avatarImage, originatingNotificationID: localNotificationID)
			case .noImage:
				self?.applyAgentImageIfNotReused(nil, originatingNotificationID: localNotificationID)
			}
		}
	}

	func redraw()
	{
		guard let notification else { return }

		let accountEmojis = notification.account.cacheableEmojis

		var interactionLabelText: String

		switch notification.type
		{
		case .follow:
			interactionLabelText = 🔠("%@ followed you", notification.authorName)
		case .follow_request:
			interactionLabelText = 🔠("%@ requested to follow you", notification.authorName)
		default:
			return
		}

		interactionLabel.set(stringValue: interactionLabelText,
		                     applyingAttributes: fontService().followAttributes(),
		                     applyingEmojis: accountEmojis)

		userBioLabel.set(attributedStringValue: notification.account.attributedNote,
		                 applyingAttributes: fontService().userBioAttributes(),
		                 applyingEmojis: accountEmojis)
	}

	private func applyAgentImageIfNotReused(_ image: NSImage?, originatingNotificationID: String)
	{
		DispatchQueue.main.async
		{ [weak self] in
			// Make sure that the notification view hasn't been reused since this fetch was dispatched.
			guard self?.displayedNotificationId == originatingNotificationID
			else
			{
				return
			}

			self?.agentAvatarButton.image = image ?? #imageLiteral(resourceName: "missing")
		}
	}

	override func prepareForReuse()
	{
		super.prepareForReuse()

		displayedNotificationId = nil

		interactionLabel.stringValue = ""
		agentAvatarButton.image = #imageLiteral(resourceName: "missing")
		userAccountLabel.stringValue = ""
		userBioLabel.stringValue = ""
		timeLabel.stringValue = ""
	}

	@IBAction func showAccount(_ sender: Any?)
	{
		agentAccount.map { interactionHandler?.show(account: $0) }
	}

	@IBAction func acceptRequest(_ sender: Any)
	{
		guard let agentAccount else { return }

		respondToFollowRequest(apiRequest: FollowRequests.authorize(id: agentAccount.id))
	}

	@IBAction func declineRequest(_ sender: Any)
	{
		guard let agentAccount else { return }

		respondToFollowRequest(apiRequest: FollowRequests.reject(id: agentAccount.id))
	}

	func respondToFollowRequest(apiRequest: Request<Empty>)
	{
		guard let client = interactionHandler?.client
		else
		{ return }

		client.run(apiRequest)
		{
			_ in
		}
	}
}

extension FollowCellView: AttributedLabelLinkHandler
{
	func handle(linkURL: URL)
	{
		interactionHandler?.handle(linkURL: linkURL, knownTags: displayedNotificationTags)
	}
}

extension FollowCellView: RichTextCapable
{
	func set(shouldDisplayAnimatedContents animates: Bool)
	{
		interactionLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
		userBioLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
	}
}
