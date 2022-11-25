//
//  AuthorizedAccount.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 03.01.19.
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

extension AuthorizedAccount
{
	func setLists(_ lists: [List]) throws
	{
		for list in lists
		{
			let accountReference = try FollowedList.fetchOrInsert(for: list, authorizedAccount: self)
			accountReference.authorizedAccount = self
		}
	}
	
	func setBlockedAccounts(_ accounts: [Account]) throws
	{
		try updateRelationship(keyPath: \AccountReference.isBlocked, using: accounts)
	}

	func setMutedAccounts(_ accounts: [Account]) throws
	{
		try updateRelationship(keyPath: \AccountReference.isMuted, using: accounts)
	}

	func setFollowerAccounts(_ accounts: [Account]) throws
	{
		try updateRelationship(keyPath: \AccountReference.isFollower, using: accounts)
	}

	func setFollowingAccounts(_ accounts: [Account]) throws
	{
		try updateRelationship(keyPath: \AccountReference.isFollowing, using: accounts)
	}

	func updateRelationship(keyPath: WritableKeyPath<AccountReference, Bool>, using accounts: [Account]) throws
	{
		relationships?.forEach()
			{
				if var accountReference = $0 as? AccountReference
				{
					accountReference[keyPath: keyPath] = false
				}
			}

		for account in accounts
		{
			var accountReference = try AccountReference.fetchOrInsert(for: account, authorizedAccount: self)
			accountReference[keyPath: keyPath] = true
			accountReference.authorizedAccount = self
		}
	}

	func isSameUser(as anotherAccount: Account) -> Bool
	{
		return anotherAccount.username == username && anotherAccount.url.host == baseDomain
	}
}
