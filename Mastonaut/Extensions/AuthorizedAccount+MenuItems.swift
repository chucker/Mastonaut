//
//  AuthorizedAccount+MenuItems.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 21.02.19.
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

import Foundation
import CoreTootin

extension Array where Element == AuthorizedAccount
{
	func makeMenuItems(currentUser: UUID?,
					   action: Selector,
					   target: AnyObject,
					   emojiContainer: NSView?,
					   setKeyEquivalents: Bool) -> (menuItems: [NSMenuItem], selectedItem: NSMenuItem?)
	{
		var menuItems = [NSMenuItem]()
		var selectedItem: NSMenuItem? = nil

		let displayNames = Set(map(\.bestDisplayName))

		for (index, account) in enumerated()
		{
			let emoji = account.baseDomain.map { AppDelegate.shared.customEmojiCache.cachedEmoji(forInstance: $0) }

			let itemHasKeyEquivalent = setKeyEquivalents && index < 9
			let itemTitle = account.bestDisplayName
			let menuItem = NSMenuItem(title: itemTitle,
									  action: action,
									  keyEquivalent: itemHasKeyEquivalent ? "\(index + 1)" : "")

			let attributedTitle = itemTitle.applyingEmojiAttachments(emoji ?? [],
																	 staticOnly: true,
																	 font: NSFont.menuFont(ofSize: NSFont.systemFontSize),
																	 containerView: emojiContainer)
											.mutableCopy() as! NSMutableAttributedString

			if attributedTitle.length != (itemTitle as NSString).length
			{
				attributedTitle.addAttribute(.font,
											 value: NSFont.menuFont(ofSize: 13),
											 range: NSMakeRange(0, attributedTitle.length))

				menuItem.attributedTitle = attributedTitle
			}

			if displayNames.count != count, let domain = account.baseDomain {
				attributedTitle.append(NSAttributedString(string: "\n"))
				attributedTitle.setAttributes([.font: NSFont.menuFont(ofSize: 13)],
													 range: NSMakeRange(0, attributedTitle.length))

				let instanceAttributedString = NSAttributedString(string: domain,
																  attributes: [.font: NSFont.menuFont(ofSize: 9)])
				attributedTitle.append(instanceAttributedString)
				menuItem.attributedTitle = attributedTitle
			}

			menuItem.target = target
			menuItem.representedObject = account.uuid
			menuItem.keyEquivalentModifierMask = itemHasKeyEquivalent ? .command : []
			menuItem.image = account.avatarImage
			menuItems.append(menuItem)

			if currentUser == account.uuid
			{
				selectedItem = menuItem
				menuItem.state = .on
			}
		}

		if selectedItem == nil
		{
			let menuItem = NSMenuItem(title: 🔠("Please Select…"), action: nil, keyEquivalent: "")
			menuItem.isEnabled = false
			menuItems.insert(menuItem, at: 0)
			selectedItem = menuItem
		}

		menuItems.append(.separator())

		let addUserItem = NSMenuItem(title: 🔠("Add Account…"),
									 action: #selector(AppDelegate.newAuthorization(_:)),
									 keyEquivalent: setKeyEquivalents ? "A" : "")
		addUserItem.keyEquivalentModifierMask = setKeyEquivalents ? [.command, .shift] : []
		addUserItem.target = AppDelegate.shared

		menuItems.append(addUserItem)

		return (menuItems, selectedItem)
	}
}
