//
//  InteractionCellView.swift
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

class InteractionCellView: MastonautTableCellView, NotificationDisplaying
{
	@IBOutlet private unowned var stackView: NSStackView!
	@IBOutlet private unowned var interactionIcon: NSImageView!
	@IBOutlet private unowned var interactionLabel: NSButton!
	@IBOutlet private unowned var agentAvatarButton: NSButton!
	@IBOutlet private unowned var authorAvatarButton: NSButton!
	@IBOutlet private unowned var authorNameLabel: NSButton!
	@IBOutlet private unowned var authorAccountLabel: NSTextField!
	@IBOutlet private unowned var contentWarningContainerView: NSView!
	@IBOutlet private unowned var contentWarningLabel: AttributedLabel!
	@IBOutlet private unowned var statusLabel: AttributedLabel!
	@IBOutlet private unowned var attachmentInfoLabel: NSTextField!
	@IBOutlet private unowned var attachmentIcon: NSImageView!
	@IBOutlet private unowned var attachmentInfoStackView: NSStackView!
	@IBOutlet private unowned var replyButton: NSButton!
	@IBOutlet private unowned var reblogButton: NSButton!
	@IBOutlet private unowned var favoriteButton: NSButton!
	@IBOutlet private unowned var timeLabel: NSTextField!

	private func fontService() -> FontService
	{
		return FontService(font: MastonautPreferences.instance.statusFont)
	}

	var displayedNotificationId: String?

	private var displayedNotificationType: NotificationType?
	private var displayedNotificationTags: [Tag]?
	private var authorAccount: Account?
	private var agentAccount: Account?

	private var notification: MastodonNotification?
	private var activeInstance: Instance?

	private var pollViewController: PollViewController?

	/// Notifications can be relative to a status, so we de technically have to comply with StatusDisplaying
	var displayedStatusId: String?

	private unowned var interactionHandler: NotificationInteractionHandling?

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
		statusLabel.linkTextAttributes = fontService().statusLinkAttributes()

		redraw()
	}

	override var backgroundStyle: NSView.BackgroundStyle
	{
		didSet
		{
			guard let notificationType = displayedNotificationType
			else
			{
				return
			}

			let emphasized = backgroundStyle == .emphasized
			statusLabel.isEmphasized = emphasized

			switch notificationType
			{
			case .reblog:
				interactionIcon.image = emphasized ? #imageLiteral(resourceName: "retooted") : #imageLiteral(resourceName: "retooted_active")

			case .favourite:
				interactionIcon.image = emphasized ? #imageLiteral(resourceName: "favorited") : #imageLiteral(resourceName: "favorited_active")

			case .poll:
				interactionIcon.image = #imageLiteral(resourceName: "poll")

			case .follow:
				// This type of notification is handled by a different notification cell view.
				break

			case .mention:
				// This type of notification is handled by adapting a status cell view.
				break

			default:
				// This should have been catch beforereaching the UI level.
				break
			}

			if #available(OSX 10.14, *) {} else
			{
				statusLabel.isEmphasized = emphasized

				let effectiveColor: NSColor = emphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
				authorAccountLabel.textColor = effectiveColor
				timeLabel.textColor = effectiveColor
				attachmentInfoLabel.textColor = effectiveColor
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
		displayedNotificationType = notification.type
		displayedStatusId = notification.status?.id

		self.interactionHandler = interactionHandler
		displayedNotificationTags = notification.status?.tags

		contentWarningLabel.linkHandler = self
		statusLabel.linkHandler = self

		authorAccount = notification.status?.account
		agentAccount = notification.account

		self.activeInstance = activeInstance

		redraw()
	}

	func redraw()
	{
		guard let notification, let activeInstance else { return }

		let interactionMessage: String
		let status = notification.status
		let messageAttributes: [NSAttributedString.Key: AnyObject]

		switch notification.type
		{
		case .reblog:
			interactionIcon.image = #imageLiteral(resourceName: "retooted_active")
			interactionMessage = 🔠("%@ boosted", notification.authorName)
			messageAttributes = fontService().reblogAttributes()
			set(status: status, activeInstance: activeInstance)

		case .favourite:
			interactionIcon.image = #imageLiteral(resourceName: "favorited_active")
			interactionMessage = 🔠("%@ favorited", notification.authorName)
			messageAttributes = fontService().favoriteAttributes()
			set(status: status, activeInstance: activeInstance)

		case .poll:
			interactionIcon.image = #imageLiteral(resourceName: "poll")
			interactionMessage = 🔠("A poll has ended")
			messageAttributes = fontService().interactionAttributes()
			set(status: status, activeInstance: activeInstance)

		case .follow:
			// This type of notification is handled by a different notification cell view.
			return

		case .mention:
			// This type of notification is handled by adapting a status cell view.
			return

		default:
			// This should have been catch beforereaching the UI level.
			return
		}

		interactionLabel.set(stringValue: interactionMessage,
		                     applyingAttributes: messageAttributes,
		                     applyingEmojis: notification.account.cacheableEmojis)

		authorAvatarButton.image = #imageLiteral(resourceName: "missing")
		agentAvatarButton.image = #imageLiteral(resourceName: "missing")

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

		if let account = notification.status?.account
		{
			AppDelegate.shared.avatarImageCache.fetchImage(account: account)
			{ [weak self] result in
				switch result
				{
				case .inCache(let avatarImage):
					assert(Thread.isMainThread)
					self?.authorAvatarButton.image = avatarImage
				case .loaded(let avatarImage):
					self?.applyAuthorImageIfNotReused(avatarImage, originatingNotificationID: localNotificationID)
				case .noImage:
					self?.applyAuthorImageIfNotReused(nil, originatingNotificationID: localNotificationID)
				}
			}
		}
	}

	func setHasActivePollTask(_ hasTask: Bool)
	{
		pollViewController?.setHasActiveReloadTask(hasTask)
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

	private func applyAuthorImageIfNotReused(_ image: NSImage?, originatingNotificationID: String)
	{
		DispatchQueue.main.async
		{ [weak self] in
			// Make sure that the notification view hasn't been reused since this fetch was dispatched.
			guard self?.displayedNotificationId == originatingNotificationID
			else
			{
				return
			}

			self?.authorAvatarButton.image = image ?? #imageLiteral(resourceName: "missing")
		}
	}

	private func set(attachmentCount: Int)
	{
		if attachmentCount > 0
		{
			attachmentInfoStackView.isHidden = false
			attachmentIcon.image = #imageLiteral(resourceName: "attachment")
			attachmentInfoLabel.stringValue = attachmentCount == 1 ? 🔠("one attachment")
				: 🔠("%@ attachments", String(attachmentCount))
		}
		else
		{
			attachmentInfoStackView.isHidden = true
		}
	}

	private func set(authorName: String, account: String, emojis: [CacheableEmoji])
	{
		authorNameLabel.set(stringValue: authorName,
		                    applyingAttributes: fontService().authorAttributes(),
		                    applyingEmojis: emojis)

		authorAccountLabel.stringValue = account
	}

	private func set(creationTime: Date)
	{
		timeLabel.objectValue = creationTime
		timeLabel.toolTip = DateFormatter.longDateFormatter.string(from: creationTime)
	}

	private func set(status: Status?, activeInstance: Instance)
	{
		guard let status = status
		else
		{
			statusLabel.isHidden = true
			set(attachmentCount: 0)
			return
		}

		if status.spoilerText.isEmpty
		{
			contentWarningContainerView.isHidden = true
		}
		else
		{
			contentWarningContainerView.isHidden = false
			contentWarningLabel.set(attributedStringValue: status.attributedSpoiler,
			                        applyingAttributes: fontService().statusAttributes(),
			                        applyingEmojis: status.cacheableEmojis)
		}

		let attributedStatusContent = status.fullAttributedContent

		if attributedStatusContent.isEmpty
		{
			statusLabel.isHidden = true
		}
		else
		{
			statusLabel.isHidden = false
			statusLabel.set(attributedStringValue: attributedStatusContent,
			                applyingAttributes: fontService().statusAttributes(),
			                applyingEmojis: status.cacheableEmojis)
		}

		reblogButton.isEnabled = status.visibility.allowsReblog
		reblogButton.toolTip = status.visibility.reblogToolTip(didReblog: status.reblogged == true)
		reblogButton.image = status.visibility.reblogIcon

		reblogButton.state = status.reblogged == true ? .on : .off
		favoriteButton.state = status.favourited == true ? .on : .off

		set(authorName: status.authorName,
		    account: status.account.uri(in: activeInstance),
		    emojis: status.account.cacheableEmojis)

		set(attachmentCount: status.mediaAttachments.count)
		set(creationTime: status.createdAt)

		if let poll = status.poll
		{
			let viewController = PollViewController()
			viewController.set(poll: poll)

			stackView.addArrangedSubview(viewController.view)
			pollViewController = viewController

			stackView.widthAnchor.constraint(equalTo: viewController.view.widthAnchor).isActive = true
		}
	}

	func set(updatedPoll: Poll)
	{
		pollViewController?.set(poll: updatedPoll)
	}

	override func prepareForReuse()
	{
		super.prepareForReuse()

		displayedNotificationId = nil
		displayedNotificationType = nil
		interactionIcon.image = nil
		authorAvatarButton.image = #imageLiteral(resourceName: "missing")
		interactionLabel.stringValue = ""
		authorNameLabel.stringValue = ""
		authorAccountLabel.stringValue = ""
		statusLabel.stringValue = ""
		attachmentInfoLabel.stringValue = ""
		timeLabel.stringValue = ""

		pollViewController?.view.removeFromSuperview()
		pollViewController = nil
	}

	@IBAction private func interactionButtonClicked(_ sender: NSButton)
	{
		guard let interactedNotificationId = displayedNotificationId
		else
		{
			return
		}

		switch (sender, sender.state)
		{
		case (favoriteButton, .on):
			interactionHandler?.favoriteStatus(for: self)
			{
				[weak self] success in

				DispatchQueue.main.async
				{
					guard self?.displayedNotificationId == interactedNotificationId else { return }
					self?.favoriteButton.state = success ? .on : .off
				}
			}

		case (favoriteButton, .off):
			interactionHandler?.unfavoriteStatus(for: self)
			{
				[weak self] success in

				DispatchQueue.main.async
				{
					guard self?.displayedNotificationId == interactedNotificationId else { return }
					self?.favoriteButton.state = success ? .off : .on
				}
			}

		case (reblogButton, .on):
			interactionHandler?.reblogStatus(for: self)
			{
				[weak self] success in

				DispatchQueue.main.async
				{
					guard self?.displayedNotificationId == interactedNotificationId else { return }
					self?.reblogButton.state = success ? .on : .off
				}
			}

		case (reblogButton, .off):
			interactionHandler?.unreblogStatus(for: self)
			{
				[weak self] success in

				DispatchQueue.main.async
				{
					guard self?.displayedNotificationId == interactedNotificationId else { return }
					self?.reblogButton.state = success ? .off : .on
				}
			}

		case (replyButton, _):
			guard let statusID = displayedStatusId
			else
			{
				return
			}

			interactionHandler?.reply(to: statusID)

		case (authorNameLabel, _), (authorAvatarButton, _):
			authorAccount.map { interactionHandler?.show(account: $0) }

		case (interactionLabel, _), (agentAvatarButton, _):
			agentAccount.map { interactionHandler?.show(account: $0) }

		default: break
		}
	}
}

extension InteractionCellView: AttributedLabelLinkHandler
{
	func handle(linkURL: URL)
	{
		interactionHandler?.handle(linkURL: linkURL, knownTags: displayedNotificationTags)
	}
}

extension InteractionCellView: RichTextCapable
{
	func set(shouldDisplayAnimatedContents animates: Bool)
	{
		interactionLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
		authorNameLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
		statusLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
		contentWarningLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
	}
}
