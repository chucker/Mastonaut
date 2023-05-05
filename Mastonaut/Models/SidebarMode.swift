//
//  SidebarMode.swift
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

import Foundation
import MastodonKit
import CoreTootin

enum SidebarMode: RawRepresentable, SidebarModel, Equatable
{
	typealias RawValue = String

	case profile(uri: String, account: Account?)
	case tag(String)
	case status(uri: String, status: Status?)
	case favorites
	case edits(status: Status?, edits: [StatusEdit]?)

	var rawValue: String
	{
		switch self
		{
		case .profile(let uri, _):
			return "profile\n\(uri)"

		case .tag(let tagName):
			return "tag\n\(tagName)"

		case .status(let tagName, _):
			return "status\n\(tagName)"

		case .favorites:
			return "favorites"
			
		case .edits(let status, _):
			return "edits\n\(status?.id ?? "")"
		}
	}

	static func profile(uri: String) -> SidebarMode
	{
		return .profile(uri: uri, account: nil)
	}

	init?(rawValue: String)
	{
		let components = rawValue.split(separator: "\n")

		if components.count == 2
		{
			if components.first == "profile"
			{
				self = .profile(uri: String(components[1]), account: nil)
			}
			else if components.first == "tag"
			{
				self = .tag(String(components[1]))
			}
			else if components.first == "status"
			{
				self = .status(uri: String(components[1]), status: nil)
			}
			else if components.first == "edits"
			{
				self = .edits(status: nil, edits: nil)
			}
			else
			{
				return nil
			}
		}
		else if components.count == 1, components.first == "favorites"
		{
			self = .favorites
		}
		else
		{
			return nil
		}
	}

	func makeViewController(client: ClientType,
							currentAccount: AuthorizedAccount?,
							currentInstance: Instance) -> SidebarViewController
	{
		switch self
		{
		case .profile(let uri, nil):
			return ProfileViewController(uri: uri, currentAccount: currentAccount, client: client)

		case .profile(_, .some(let account)):
			return ProfileViewController(account: account, instance: currentInstance)

		case .tag(let tag):
			let bookmarkService = currentAccount.map { TagBookmarkService(account: $0) }
			let followService = currentAccount.map { TagFollowService(account: $0, client: client) }
			
			return TagViewController(tag: tag, tagBookmarkService: bookmarkService, tagFollowService: followService)

		case .status(let uri, nil):
			return StatusThreadViewController(uri: uri, client: client)

		case .status(_, .some(let status)):
			return StatusThreadViewController(status: status)

		case .favorites:
			return FavoritesViewController()
			
		case .edits(let status, let edits):
			return EditHistoryViewController(status: status, edits: edits)
		}
	}

	static func == (lhs: SidebarMode, rhs: SidebarMode) -> Bool
	{
		switch (lhs, rhs)
		{
		case (.profile(let a1, _), .profile(let a2, _)):
			return a1 == a2

		case (.tag(let tag1), .tag(let tag2)):
			return tag1 == tag2

		case (.status(let s1, _), .status(let s2, _)):
			return s1 == s2

		default:
			return false
		}
	}
}
