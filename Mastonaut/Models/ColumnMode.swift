//
//  ColumnMode.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 14.04.19.
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

enum ColumnMode: RawRepresentable, ColumnModel, Equatable, Comparable
{
	typealias RawValue = String

	case timeline
	case localTimeline
	case publicTimeline
	case notifications

	case favorites
	case bookmarks

	case list(list: FollowedList)
	case tag(name: String)

	var rawValue: RawValue
	{
		switch self
		{
		case .timeline: return "timeline"
		case .localTimeline: return "localTimeline"
		case .publicTimeline: return "publicTimeline"
		case .notifications: return "notifications"

		case .favorites: return "favorites"
		case .bookmarks: return "bookmarks"

		case .list(let list): return "list:\(list.title ?? "")"
		case .tag(let name): return "tag:\(name)"
		}
	}

	init?(rawValue: RawValue)
	{
		switch rawValue
		{
		case "timeline": self = .timeline
		case "localTimeline": self = .localTimeline
		case "publicTimeline": self = .publicTimeline
		case "notifications": self = .notifications

		case "favorites": self = .favorites
		case "bookmarks": self = .bookmarks

//		case let rawValue where rawValue.hasPrefix("list:"):
//			let id = rawValue.suffix(from: rawValue.index(after: rawValue.range(of: "list:")!.upperBound))
//			self = .list(list: List(from: <#T##Decoder#>) String(name))

		case let rawValue where rawValue.hasPrefix("tag:"):
			let name = rawValue.suffix(from: rawValue.index(after: rawValue.range(of: "tag:")!.upperBound))
			self = .tag(name: String(name))

		default:
			return nil
		}
	}

	var weight: Int
	{
		switch self
		{
		case .timeline: return -7
		case .localTimeline: return -6
		case .publicTimeline: return -5
		case .notifications: return -4

		case .favorites: return -3
		case .bookmarks: return -2

		case .list: return -1
		case .tag: return 0
		}
	}

	func makeViewController() -> ColumnViewController
	{
		switch self
		{
		case .timeline: return TimelineViewController(source: .timeline)
		case .localTimeline: return TimelineViewController(source: .localTimeline)
		case .publicTimeline: return TimelineViewController(source: .publicTimeline)
		case .notifications: return NotificationListViewController()

		case .favorites: return TimelineViewController(source: .favorites)
		case .bookmarks: return TimelineViewController(source: .bookmarks)

		case .list(let list): return TimelineViewController(source: .list(list: list))
		case .tag(let name): return TimelineViewController(source: .tag(name: name))
		}
	}

	private func makeMenuItem() -> NSMenuItem
	{
		let menuItem = NSMenuItem()
		menuItem.representedObject = self

		switch self
		{
		case .timeline:
			menuItem.title = 🔠("Home")
			menuItem.image = #imageLiteral(resourceName: "home")

		case .localTimeline:
			menuItem.title = 🔠("Local Timeline")
			menuItem.image = #imageLiteral(resourceName: "group")

		case .publicTimeline:
			menuItem.title = 🔠("Public Timeline")
			menuItem.image = NSImage.CoreTootin.globe

		case .notifications:
			menuItem.title = 🔠("Notifications")
			menuItem.image = #imageLiteral(resourceName: "bell")

		case .favorites:
			menuItem.title = 🔠("Favorites")
			if #available(macOS 11.0, *) {
				menuItem.image = NSImage(systemSymbolName: "star", accessibilityDescription: "Favorites")
			}

		case .bookmarks:
			menuItem.title = 🔠("Bookmarks")
			if #available(macOS 11.0, *) {
				menuItem.image = NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Bookmarks")
			}

		case .list(let list):
			menuItem.title = 🔠(list.title!)
			if #available(macOS 11.0, *) {
				menuItem.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "List")
			} 

		case .tag(let name):
			menuItem.title = 🔠("Tag: %@", name)
			menuItem.image = #imageLiteral(resourceName: "bell") // FIXME: I don't think that's the right image?
		}

		return menuItem
	}

	var menuItemSection: Int
	{
		switch self
		{
		case .timeline, .localTimeline, .publicTimeline, .notifications: return 0

		case .favorites: return 1
		case .bookmarks: return 1

		case .list: return 2

		case .tag: return 3
		}
	}

	func makeMenuItemForAdding(with target: AnyObject) -> NSMenuItem
	{
		let menuItem = self.makeMenuItem()
		menuItem.target = target
		menuItem.action = #selector(TimelinesWindowController.addColumnMode(_:))
		return menuItem
	}

	func makeMenuItemForChanging(with target: AnyObject, columnId: Int) -> NSMenuItem
	{
		let menuItem = self.makeMenuItem()
		menuItem.tag = columnId
		menuItem.target = target
		menuItem.action = #selector(TimelinesWindowController.changeColumnMode(_:))
		return menuItem
	}

	/// Instance-wide column modes
	static var staticItems: [ColumnMode]
	{
		return [.timeline, .localTimeline, .publicTimeline, .notifications]
	}

	/// Personal column modes that are always available (as opposed to lists, hashtags, etc.)
	static var staticPersonalItems: [ColumnMode]
	{
		return [.favorites, .bookmarks]
	}

	static func == (lhs: ColumnMode, rhs: ColumnMode) -> Bool
	{
		switch (lhs, rhs)
		{
		case (.timeline, .timeline):
			return true
		case (.localTimeline, .localTimeline):
			return true
		case (.publicTimeline, .publicTimeline):
			return true
		case (.notifications, .notifications):
			return true

		case (.favorites, .favorites):
			return true
		case (.bookmarks, .bookmarks):
			return true

		case (.list(let leftList), .list(let rightList)):
			return leftList.id == rightList.id
		case (.tag(let leftTag), .tag(let righTag)):
			return leftTag == righTag
		default:
			return false
		}
	}

	static func < (lhs: ColumnMode, rhs: ColumnMode) -> Bool
	{
		if lhs.weight != rhs.weight
		{
			return lhs.weight < rhs.weight
		}

		switch (lhs, rhs)
		{
		case (.tag(let leftTag), .tag(let rightTag)):
			return leftTag < rightTag

		default:
			return false
		}
	}
}
