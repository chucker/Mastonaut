//
//  AuthorizedAccount+Helpers.swift
//  CoreTootin
//
//  Created by Bruno Philipe on 16.09.19.
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

import CoreData
import MastodonKit

public extension AuthorizedAccount
{
	func preferences(context: NSManagedObjectContext) -> AccountPreferences
	{
		if let preferences = self.accountPreferences
		{
			return preferences
		}

		let preferences = AccountPreferences(context: managedObjectContext ?? context)
		self.accountPreferences = preferences
		return preferences
	}
	
	func notificationPreferences(context: NSManagedObjectContext) -> AccountNotificationPreferences
	{
		if let notificationPreferences = self.accountNotificationPreferences
		{
			return notificationPreferences
		}

		let notificationPreferences = AccountNotificationPreferences(context: managedObjectContext ?? context)
		self.accountNotificationPreferences = notificationPreferences
		return notificationPreferences
	}

	static func insert(context: NSManagedObjectContext,
					   account: String,
					   baseDomain: String,
					   displayName: String,
					   username: String,
					   avatarURL: URL?,
					   uri: String,
					   login: LoginSettings) -> AuthorizedAccount
	{
		let authorizedAccount = AuthorizedAccount(context: context)

		authorizedAccount.account = account
		authorizedAccount.baseDomain = baseDomain
		authorizedAccount.accessTokenType = login.accessTokenType
		authorizedAccount.createdAt = Date(timeIntervalSince1970: login.createdAt)
		authorizedAccount.uuidString = UUID().uuidString
		authorizedAccount.displayName = displayName
		authorizedAccount.username = username
		authorizedAccount.avatarURL = avatarURL
		authorizedAccount.uri = uri

		return authorizedAccount
	}

	static func fetchAll(context: NSManagedObjectContext) throws -> [AuthorizedAccount]
	{
		let request: NSFetchRequest<AuthorizedAccount> = fetchRequest()
		return try context.fetch(request)
	}

	static func fetch(with uuid: UUID, context: NSManagedObjectContext) throws -> AuthorizedAccount
	{
		let request: NSFetchRequest<AuthorizedAccount> = fetchRequest()
		request.predicate = NSPredicate(format: "uuidString = %@", uuid.uuidString)
		if let account = try context.fetch(request).first
		{
			return account
		}
		else
		{
			throw FetchError.notFound
		}
	}

	func updateLocalInfo(using account: Account, instance: Instance)
	{
		displayName = account.displayName
		username = account.username
		avatarURL = account.avatarURL
		uri = account.uri(in: instance)
	}

	var uuid: UUID
	{
		guard let uuid = uuidString.flatMap({ UUID(uuidString: $0) }) else {
			let newUUID = UUID()

			if !isFault, !isDeleted
			{
				uuidString = newUUID.uuidString
			}

			return newUUID
		}

		return uuid
	}

	var bestDisplayName: String
	{
		guard let displayName = self.displayName, !displayName.isEmpty else
		{
			return username!
		}

		return displayName
	}

	var accountWithInstance: String
	{
		return isFault ? "" : (uri ?? "@\(username!)@\(baseDomain!)")
	}

	enum FetchError: Error
	{
		case notFound
	}
}

public extension AuthorizedAccount
{
	var bookmarkedTagsList: [String]
	{
		let tags = (bookmarkedTags as? Set<BookmarkedTag>) ?? []
		return tags.map({ $0.name! }).sorted()
	}

	func hasBookmarkedTag(_ tagName: String) -> Bool
	{
		return bookmarkedTag(with: tagName) != nil
	}

	func bookmarkTag(_ tagName: String)
	{
		guard !isDeleted, hasBookmarkedTag(tagName) == false else { return }
		let tag = BookmarkedTag(context: managedObjectContext!)
		tag.name = tagName
		addToBookmarkedTags(tag)
	}

	func unbookmarkTag(_ tagName: String)
	{
		guard !isDeleted, let tag = bookmarkedTag(with: tagName) else { return }
		removeFromBookmarkedTags(tag)
	}

	private func bookmarkedTag(with name: String) -> BookmarkedTag?
	{
		let fetchRequest: NSFetchRequest<BookmarkedTag> = BookmarkedTag.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "account = %@ AND name = %@", self, name)
		return try! managedObjectContext!.fetch(fetchRequest).first
	}

	func hasFollowedTag(_ tagName: String, client: ClientType) async -> Bool
	{
		let followedTags = try? await client.run(Tags.followed())

		let filtered = followedTags?.value.filter { $0.name == tagName }

		return filtered?.count ?? 0 > 0
	}

	func followTag(_ tagName: String, client: ClientType) async
	{
		_ = try? await client.run(Tags.follow(name: tagName))
	}

	func unfollowTag(_ tagName: String, client: ClientType) async
	{
		_ = try? await client.run(Tags.unfollow(name: tagName))
	}
}
