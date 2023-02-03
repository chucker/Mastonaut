//
//  StatusMenuItemsController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 11.05.19.
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

class MenuItemsController: NSObject
{
	fileprivate func makeActionItem(title: String, _ block: @escaping () -> Void) -> NSMenuItem
	{
		let item = NSMenuItem(title: title, action: #selector(evaluateRepresentedObject(_:)), keyEquivalent: "")
		item.target = self
		item.representedObject = LazyEvaluationAdapter<Void>(block)
		return item
	}

	fileprivate func makeCopyItem(title: String, _ object: Any) -> NSMenuItem
	{
		let item = NSMenuItem(title: title, action: #selector(copyRepresentedObject(_:)), keyEquivalent: "")
		item.target = self
		item.representedObject = object
		return item
	}

	fileprivate func makeStringCopyItem(title: String, _ string: String) -> NSMenuItem
	{
		return makeCopyItem(title: title, string)
	}

	fileprivate func makeLazyCopyItem(title: String, _ block: @escaping () -> NSPasteboardWriting) -> NSMenuItem
	{
		return makeCopyItem(title: title, LazyEvaluationAdapter(block))
	}

	fileprivate func makeOpenURLInBrowser(title: String, url: URL) -> NSMenuItem
	{
		return makeActionItem(title: title) { NSWorkspace.shared.open(url) }
	}

	fileprivate func makeShareItem(url: URL) -> NSMenuItem
	{
		let shareMenuItem = NSMenuItem(title: 🔠("Share"), submenu: NSMenu(title: ""))

		DispatchQueue.global(qos: .background).async
		{
			let shareMenuItems = ShareMenuFactory.shareMenuItems(for: url)

			if shareMenuItems.isEmpty
			{
				shareMenuItem.isHidden = true
			}
			else
			{
				shareMenuItem.submenu?.setItems(shareMenuItems)
			}
		}

		return shareMenuItem
	}
}

class StatusMenuItemsController: MenuItemsController
{
	static let shared = StatusMenuItemsController()

	func menuItems(forFilteredStatus status: Status, interactionHandler: StatusInteractionHandling) -> [NSMenuItem]
	{
		return [makeShowDetailsItem(status: status, interactionHandler: interactionHandler)]
	}

	func menuItems(for status: Status, interactionHandler handler: StatusInteractionHandling) -> [NSMenuItem]
	{
		let author = status.reblog?.account ?? status.account

		var items: [NSMenuItem] = [
			makeShowDetailsItem(status: status, interactionHandler: handler),
			makeShowAccountItem(account: status.account, interactionHandler: handler),
			(status.reblog?.account).map { makeShowAccountItem(account: $0, interactionHandler: handler) },
			.separator(),
			makeItemCopyStatusTextContents(status),
			makeItemCopyLinkToStatus(status),
			.separator(),
			makeBoostItem(status, interactionHandler: handler),
			makeFavoriteItem(status, interactionHandler: handler),
			makeBookmarkItem(status, interactionHandler: handler),
			.separator(),
			makeActionItem(title: 🔠("Mention @\(author.username)…"))
			{ handler.mention(userHandle: "@\(author.acct)", directMessage: false) },
			makeActionItem(title: 🔠("Direct message @\(author.username)…"))
			{ handler.mention(userHandle: "@\(author.acct)", directMessage: true) }
		].compacted()

		if handler.canDeleteOrEdit(status: status)
		{
			items.append(.separator())
			items.append(contentsOf: makeDeleteStatusItems(status: status, interactionHandler: handler))
			items.append(contentsOf: makeEditStatusItem(status: status, interactionHandler: handler))
		}

		if handler.canPin(status: status)
		{
			items.append(.separator())
			items.append(makePinOrUnpinStatusItem(status: status, interactionHandler: handler))
		}

		var mentions = status.reblog?.mentions ?? status.mentions
		if !mentions.isEmpty
		{
			// Avoid showing the author handle twice
			mentions.removeAll(where: { $0.acct == status.account.acct })

			items.append(.separator())
			items.append(contentsOf: mentions.map { makeShowMentionItem(mention: $0,
			                                                            interactionHandler: handler) })
		}

		let tags = status.reblog?.tags ?? status.tags
		if !tags.isEmpty
		{
			items.append(.separator())
			items.append(contentsOf: tags.map { makeShowTagItem(tag: $0, interactionHandler: handler) })
		}

		let links = status.reblog?.links ?? status.links
		if !links.isEmpty
		{
			items.append(.separator())
			items.append(contentsOf: links.map { makeOpenURLInBrowser(title: $0.value, url: $0.key) })
		}

		if let poll = (status.reblog?.poll ?? status.poll), poll.expired || poll.voted == true
		{
			items.append(.separator())
			items.append(makeReloadPollItem(poll: poll, status: status, interactionHandler: handler))
		}

		if let url = status.reblog?.url ?? status.url
		{
			items.append(.separator())
			items.append(makeOpenURLInBrowser(title: 🔠("Open toot in Browser"), url: url))

			items.append(.separator())
			items.append(makeShareItem(url: url))
		}

		return items
	}

	private func makeBoostItem(_ status: Status, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		if !(status.reblogged ?? false)
		{
			return makeActionItem(title: 🔠("Boost Toot")) { interactionHandler.reblogStatus(with: status.id) { _ in } }
		}
		else
		{
			return makeActionItem(title: 🔠("Unboost Toot")) { interactionHandler.unreblogStatus(with: status.id) { _ in } }
		}
	}

	private func makeFavoriteItem(_ status: Status, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		if !(status.favourited ?? false)
		{
			return makeActionItem(title: 🔠("Favorite Toot")) { interactionHandler.favoriteStatus(with: status.id) { _ in } }
		}
		else
		{
			return makeActionItem(title: 🔠("Unfavorite Toot")) { interactionHandler.unfavoriteStatus(with: status.id) { _ in } }
		}
	}

	private func makeBookmarkItem(_ status: Status, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		if !(status.bookmarked ?? false)
		{
			return makeActionItem(title: 🔠("Bookmark Toot")) { interactionHandler.bookmarkStatus(with: status.id) { _ in } }
		}
		else
		{
			return makeActionItem(title: 🔠("Unbookmark Toot")) { interactionHandler.unbookmarkStatus(with: status.id) { _ in } }
		}
	}

	private func makeItemCopyStatusTextContents(_ status: Status) -> NSMenuItem
	{
		return makeLazyCopyItem(title: 🔠("Copy toot text")) { status.attributedContent.string as NSString }
	}

	private func makeItemCopyLinkToStatus(_ status: Status) -> NSMenuItem
	{
		let finalStatus = status.reblog ?? status
		return makeStringCopyItem(title: 🔠("Copy link to toot"), finalStatus.url?.absoluteString ?? finalStatus.uri)
	}

	private func makeShowDetailsItem(status: Status, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		return makeActionItem(title: 🔠("Show toot details")) { interactionHandler.show(status: status) }
	}

	private func makeDeleteStatusItems(status: Status, interactionHandler: StatusInteractionHandling) -> [NSMenuItem]
	{
		return [
			makeActionItem(title: 🔠("Delete")) { interactionHandler.delete(status: status, redraft: false) },
			makeActionItem(title: 🔠("Delete & Re-draft")) { interactionHandler.delete(status: status, redraft: true) }
		]
	}

	private func makeEditStatusItem(status: Status, interactionHandler: StatusInteractionHandling) -> [NSMenuItem]
	{
		return [
			makeActionItem(title: 🔠("Edit")) { interactionHandler.edit(status: status) }
		]
	}

	private func makePinOrUnpinStatusItem(status: Status, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		if status.pinned != true
		{
			return makeActionItem(title: 🔠("Pin to Profile")) { interactionHandler.pin(status: status) }
		}
		else
		{
			return makeActionItem(title: 🔠("Unpin from Profile")) { interactionHandler.unpin(status: status) }
		}
	}

	private func makeShowAccountItem(account: Account, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		return makeActionItem(title: "@\(account.acct)") { interactionHandler.show(account: account) }
	}

	private func makeShowMentionItem(mention: Mention, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		return makeActionItem(title: "@\(mention.acct)") { interactionHandler.handle(linkURL: mention.url,
		                                                                             knownTags: nil) }
	}

	private func makeShowTagItem(tag: Tag, interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		return makeActionItem(title: "#\(tag.name)") { interactionHandler.show(tag: tag) }
	}

	private func makeReloadPollItem(poll: Poll, status: Status,
	                                interactionHandler: StatusInteractionHandling) -> NSMenuItem
	{
		return makeActionItem(title: 🔠("Reload poll results"))
		{
			interactionHandler.refreshPoll(statusID: status.id, pollID: poll.id)
		}
	}
}

class NotificationMenuItemsController: MenuItemsController
{
	static let shared = NotificationMenuItemsController()

	func menuItems(for notification: CoalescedNotification,
	               interactionHandler: NotificationInteractionHandling) -> [NSMenuItem]
	{
		var accounts: [Account]?

		switch notification
		{
		case .uncoalesced(let originalNotification):
			accounts = [originalNotification.account]
		case .rebloggedOrFavorited(let _accounts, _, _, _):
			accounts = _accounts
		case .following(let _accounts, _):
			accounts = _accounts
		}

		if let accounts
		{
			return accounts.map { makeShowAccountItem(account: $0, interactionHandler: interactionHandler) }
		}

		return []
	}

	private func makeShowAccountItem(account: Account, interactionHandler: NotificationInteractionHandling) -> NSMenuItem
	{
		return makeActionItem(title: "@\(account.acct)") { interactionHandler.show(account: account) }
	}
}

class AccountMenuItemsController: MenuItemsController
{
	static let shared = AccountMenuItemsController()

	func menuItems(for account: Account, interactionHandler handler: StatusInteractionHandling) -> [NSMenuItem]
	{
		return [
			makeActionItem(title: 🔠("Mention @\(account.username)…"))
			{
				handler.mention(userHandle: "@\(account.acct)", directMessage: false)
			},
			makeActionItem(title: 🔠("Direct message @\(account.username)…"))
			{
				handler.mention(userHandle: "@\(account.acct)", directMessage: true)
			},
			.separator(),
			makeOpenURLInBrowser(title: 🔠("Open profile in Browser"), url: account.url),
			makeStringCopyItem(title: 🔠("Copy link to profile"), account.url.absoluteString),
			makeStringCopyItem(title: 🔠("Copy profile handle"), account.acct),
			.separator(),
			makeShareItem(url: account.url)
		]
	}
}

internal extension MenuItemsController
{
	@objc func copyRepresentedObject(_ sender: NSMenuItem)
	{
		if let pasteboardWritable = sender.representedObject as? NSPasteboardWriting
		{
			NSPasteboard.general.clearContents()
			NSPasteboard.general.writeObjects([pasteboardWritable])
		}
		else if let lazyPasteboardWritable = sender.representedObject as? LazyEvaluationAdapter<NSPasteboardWriting>
		{
			NSPasteboard.general.clearContents()
			NSPasteboard.general.writeObjects([lazyPasteboardWritable.evaluate()])
		}
	}

	@objc func evaluateRepresentedObject(_ sender: NSMenuItem)
	{
		if let adapter = sender.representedObject as? LazyEvaluationAdapter<Void>
		{
			adapter.evaluate()
		}
	}
}
