//
//  AccountReference.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 07.04.19.
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

extension AccountReference
{
	fileprivate static func insertBlank() -> AccountReference
	{
		return AccountReference(context: AppDelegate.shared.managedObjectContext)
	}

	fileprivate static func insert(id: String, authorizedAccount: AuthorizedAccount) -> AccountReference
	{
		let blank = AccountReference(context: AppDelegate.shared.managedObjectContext)
		blank.identifier = id
		blank.authorizedAccount = authorizedAccount
		return blank
	}

	static func fetchRequest(id: String, authorizedAccount: AuthorizedAccount) -> NSFetchRequest<AccountReference>
	{
		let fetchRequest: NSFetchRequest<AccountReference> = self.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
											 "identifier", id,
											 "authorizedAccount", authorizedAccount.objectID)
		return fetchRequest
	}

	static func fetchRequest(ids: NSSet, authorizedAccount: AuthorizedAccount) -> NSFetchRequest<AccountReference>
	{
		let fetchRequest: NSFetchRequest<AccountReference> = self.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "(%K IN %@) AND %K == %@",
											 "identifier", ids,
											 "authorizedAccount", authorizedAccount.objectID)
		return fetchRequest
	}

	static func fetch(account: Account, authorizedAccount: AuthorizedAccount) throws -> AccountReference?
	{
		let context = AppDelegate.shared.managedObjectContext
		let fetchRequest = self.fetchRequest(id: account.id, authorizedAccount: authorizedAccount)
		return try context.fetch(fetchRequest).first
	}

	static func fetchOrInsert(for account: Account, authorizedAccount: AuthorizedAccount) throws -> AccountReference
	{
		let context = AppDelegate.shared.managedObjectContext
		let fetchRequest = self.fetchRequest(id: account.id, authorizedAccount: authorizedAccount)

		let accountReference = try context.fetch(fetchRequest).first ?? insert(id: account.id, authorizedAccount: authorizedAccount)
		accountReference.username = account.username
		accountReference.host = account.url.host
		accountReference.avatarURL = account.avatarURL

		return accountReference
	}
}

extension AccountReference
{
	func relationshipSet(with anotherAccount: Account, isSelf: Bool) -> RelationshipSet
	{
		var relationship = RelationshipSet()

		if isMastonautAuthor { relationship.formUnion(.isAuthor) }
		if isFollowing { relationship.formUnion(.following) }
		if isFollowingRequested { relationship.formUnion(.followingRequested) }
		if isFollower { relationship.formUnion(.follower) }
		if isBlocked { relationship.formUnion(.blocked) }
		if isMuted { relationship.formUnion(.muted) }
		if isSelf { relationship.formUnion(.isSelf) }

		return relationship
	}

	var isMastonautAuthor: Bool
	{
		return username == "brunoph" && host == "mastodon.technology"
	}
}
