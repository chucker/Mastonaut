//
//  StatusCellModel.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 24.12.19.
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

import CoreTootin
import Foundation
import MastodonKit

class StatusCellModel: NSObject
{
	let status: Status

	let poll: Poll?

	unowned let attachmentPresenter: AttachmentPresenting
	unowned let interactionHandler: StatusInteractionHandling
	unowned let activeInstance: Instance

	@objc private(set) dynamic
	var isFavorited: Bool

	@objc private(set) dynamic
	var isReblogged: Bool

	@objc private(set) dynamic
	var authorAvatar: NSImage

	@objc private(set) dynamic
	var agentAvatar: NSImage?

	@objc private(set) dynamic
	var contextIcon: NSImage?

	var visibleStatus: Status
	{
		return status.reblog ?? status
	}

	var author: Account
	{
		return visibleStatus.account
	}

	var agent: Account
	{
		return status.account
	}

	init(status: Status,
	     poll: Poll?,
	     attachmentPresenter: AttachmentPresenting,
	     interactionHandler: StatusInteractionHandling,
	     activeInstance: Instance)
	{
		self.status = status

		self.poll = poll

		self.attachmentPresenter = attachmentPresenter
		self.interactionHandler = interactionHandler
		self.activeInstance = activeInstance

		self.isFavorited = status.favourited == true
		self.isReblogged = status.reblogged == true

		self.authorAvatar = #imageLiteral(resourceName: "missing")

		super.init()

		loadAvatars()
	}

	func showAuthor()
	{
		interactionHandler.show(account: author)
	}

	func showAgent()
	{
		interactionHandler.show(account: agent)
	}

	func showTootDetails()
	{
		interactionHandler.show(status: visibleStatus)
	}

	func setupContextButton(_ button: NSButton, attributes: [NSAttributedString.Key: AnyObject])
	{
		if status.pinned == true
		{
			contextIcon = #imageLiteral(resourceName: "thumbtack")
			button.set(stringValue: 🔠("status.context.pinned"), applyingAttributes: attributes, applyingEmojis: [])
			button.isEnabled = false
		}
		else if status.reblog != nil
		{
			contextIcon = #imageLiteral(resourceName: "retooted")
			button.set(stringValue: 🔠("status.context.boost", agent.bestDisplayName),
			           applyingAttributes: attributes,
			           applyingEmojis: agent.cacheableEmojis)
			button.isEnabled = true
		}
		else if status.inReplyToAccountID == status.account.id
		{
			contextIcon = #imageLiteral(resourceName: "thread")
			button.set(stringValue: 🔠("status.context.thread"), applyingAttributes: attributes, applyingEmojis: [])
			button.isEnabled = true
		}
		else if status.inReplyToID != nil
		{
			contextIcon = #imageLiteral(resourceName: "replied")
			button.set(stringValue: 🔠("status.context.reply"), applyingAttributes: attributes, applyingEmojis: [])
			button.isEnabled = true
		}
		else
		{
			contextIcon = nil
			button.stringValue = ""
			button.removeAllEmojiSubviews()
			button.isEnabled = false
		}
	}

	func handle(interaction: Interaction)
	{
		switch interaction
		{
		case .favorite:
			isFavorited = true
			interactionHandler.favoriteStatus(with: status.id)
			{
				[weak self] success in DispatchQueue.main.async { self?.isFavorited = success }
			}

		case .unfavorite:
			isFavorited = false
			interactionHandler.unfavoriteStatus(with: status.id)
			{
				[weak self] success in DispatchQueue.main.async { self?.isFavorited = !success }
			}

		case .reblog:
			isReblogged = true
			interactionHandler.reblogStatus(with: status.id)
			{
				[weak self] success in DispatchQueue.main.async { self?.isReblogged = success }
			}

		case .unreblog:
			isReblogged = false
			interactionHandler.unreblogStatus(with: status.id)
			{
				[weak self] success in DispatchQueue.main.async { self?.isReblogged = !success }
			}

		case .reply:
			interactionHandler.reply(to: status.id)
		}
	}

	func openCardLink()
	{
		guard let linkURL = visibleStatus.card?.url else { return }
		interactionHandler.handle(linkURL: linkURL, knownTags: visibleStatus.tags)
	}

	func loadAvatars()
	{
		if let rebloggedStatus = status.reblog
		{
			loadAccountAvatar(for: rebloggedStatus) { [weak self] in self?.authorAvatar = $0 }
			loadAccountAvatar(for: status) { [weak self] in self?.agentAvatar = $0 }
		}
		else
		{
			loadAccountAvatar(for: status) { [weak self] in self?.authorAvatar = $0 }
		}
	}

	func loadAccountAvatar(for status: Status, completion: @escaping (NSImage) -> Void)
	{
		AppDelegate.shared.avatarImageCache.fetchImage(account: status.account)
		{ result in
			switch result
			{
			case .inCache(let avatarImage):
				assert(Thread.isMainThread)
				completion(avatarImage)
			case .loaded(let avatarImage):
				DispatchQueue.main.async { completion(avatarImage) }
			case .noImage:
				DispatchQueue.main.async { completion(#imageLiteral(resourceName: "missing")) }
			}
		}
	}

	func showContextDetails()
	{
		if status.pinned == true
		{
			// NOP
		}
		else if status.reblog != nil
		{
			showAgent()
		}
		else if status.inReplyToAccountID == status.account.id
		{
			showTootDetails()
		}
		else if status.inReplyToID != nil
		{
			showTootDetails()
		}
	}

	enum Interaction
	{
		case favorite, unfavorite, reblog, unreblog, reply
	}
}

extension StatusCellModel: PollViewControllerDelegate
{
	func pollViewController(_ viewController: PollViewController,
	                        userDidVote optionIndexSet: IndexSet,
	                        completion: @escaping (Poll?) -> Void)
	{
		guard let poll = viewController.poll else { return }

		interactionHandler.voteOn(poll: poll,
		                          statusID: visibleStatus.id,
		                          options: optionIndexSet)
		{ [weak self] result in
			switch result
			{
			case .success(let updatedPoll):
				completion(updatedPoll)

			case .failure(let error):
				completion(nil)
				DispatchQueue.main.async
				{
					self?.interactionHandler.handle(interactionError: UserLocalizedDescriptionError(error))
				}
			}
		}
	}
}

extension StatusCellModel: AttributedLabelLinkHandler
{
	func handle(linkURL: URL)
	{
		interactionHandler.handle(linkURL: linkURL, knownTags: visibleStatus.tags)
	}
}
