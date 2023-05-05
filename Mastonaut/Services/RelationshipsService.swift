//
//  RelationshipsService.swift
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

struct RelationshipsService
{
	let client: ClientType
	let authorizedAccount: AuthorizedAccount

	func relationship(with account: Account, forceRefresh: Bool = false, completion: @escaping (RelationshipSet) -> Void)
	{
		let isSameUser = authorizedAccount.isSameUser(as: account)

		if !forceRefresh, let accountReference = try? AccountReference.fetch(account: account, authorizedAccount: authorizedAccount)
		{
			completion(accountReference.relationshipSet(with: account, isSelf: isSameUser))
		}
		else
		{
			client.run(Accounts.relationships(ids: [account.id]))
			{
				result in

				if case .success(let response) = result, let relationship = response.value.first
				{
					DispatchQueue.main.async
						{
							if let reference = self.store(relationship: relationship, for: account)
							{
								completion(reference.relationshipSet(with: account, isSelf: isSameUser))
							}
							else
							{
								completion(isSameUser ? .isSelf : .init())
							}
						}
				}
				else
				{
					DispatchQueue.main.async { completion(isSameUser ? .isSelf : .init()) }
				}
			}
		}
	}

	private func store(relationship: Relationship, for account: Account) -> AccountReference?
	{
		if let reference = try? AccountReference.fetchOrInsert(for: account, authorizedAccount: authorizedAccount)
		{
			reference.isMuted = relationship.muting
			reference.isFollower = relationship.followedBy
			reference.isFollowing = relationship.following
			reference.isFollowingRequested = relationship.requested
			reference.isBlocked = relationship.blocking
			
			try? reference.managedObjectContext?.save()

			return reference
		}
		else
		{
			return nil
		}
	}

	func loadBlockedAccounts(completion: @escaping (Swift.Result<[Account], Errors>) -> Void)
	{
		loadAccounts({ Blocks.all(range: $0.next ?? .default) }, completion)
	}

	func loadMutedAccounts(completion: @escaping (Swift.Result<[Account], Errors>) -> Void)
	{
		loadAccounts({ Mutes.all(range: $0.next ?? .default) }, completion)
	}

	func loadFollowerAccounts(account: Account, completion: @escaping (Swift.Result<[Account], Errors>) -> Void)
	{
		let id = account.id
		loadAccounts({ Accounts.followers(id: id, range: $0.next ?? .default) }, completion)
	}

	func loadFollowingAccounts(account: Account, completion: @escaping (Swift.Result<[Account], Errors>) -> Void)
	{
		let id = account.id
		loadAccounts({ Accounts.following(id: id, range: $0.next ?? .default) }, completion)
	}

	func follow(account: Account, completion: @escaping (Swift.Result<AccountReference, Errors>) -> Void)
	{
		setRelationship(with: account,
		                request: Accounts.follow(id: account.id),
		                persistenceSetter: {
		                	$0.isFollowing = $1.following
		                	$0.isFollowingRequested = $1.requested
		                },
		                completion: completion)
	}

	func unfollow(account: Account, completion: @escaping (Swift.Result<AccountReference, Errors>) -> Void)
	{
		setRelationship(with: account,
						request: Accounts.unfollow(id: account.id),
						persistenceSetter: { $0.isFollowing = $1.following },
						completion: completion)
	}

	func block(account: Account, completion: @escaping (Swift.Result<AccountReference, Errors>) -> Void)
	{
		setRelationship(with: account,
						request: Accounts.block(id: account.id),
						persistenceSetter: { $0.isBlocked = $1.blocking },
						completion: completion)
	}

	func unblock(account: Account, completion: @escaping (Swift.Result<AccountReference, Errors>) -> Void)
	{
		setRelationship(with: account,
						request: Accounts.unblock(id: account.id),
						persistenceSetter: { $0.isBlocked = $1.blocking },
						completion: completion)
	}

	func mute(account: Account, completion: @escaping (Swift.Result<AccountReference, Errors>) -> Void)
	{
		setRelationship(with: account,
						request: Accounts.mute(id: account.id),
						persistenceSetter: { $0.isMuted = $1.muting },
						completion: completion)
	}

	func unmute(account: Account, completion: @escaping (Swift.Result<AccountReference, Errors>) -> Void)
	{
		setRelationship(with: account,
						request: Accounts.unmute(id: account.id),
						persistenceSetter: { $0.isMuted = $1.muting },
						completion: completion)
	}

	func setRelationship(with account: Account,
						 request: Request<Relationship>,
						 persistenceSetter: @escaping (AccountReference, Relationship) -> Void,
						 completion: @escaping (Swift.Result<AccountReference, Errors>) -> Void)
	{
		client.run(request) { (result) in

			switch result
			{
			case .success(let response):
				let relationship = response.value
				
				DispatchQueue.main.async {
					do {
						let reference = try AccountReference.fetchOrInsert(for: account,
																		   authorizedAccount: self.authorizedAccount)
						persistenceSetter(reference, relationship)
						try reference.managedObjectContext?.save()

						completion(.success(reference))
					}
					catch {
						completion(.failure(.persistenceError(error)))
					}
				}

			case .failure(let error):
				completion(.failure(.networkError(error)))
			}
		}
	}

	private func loadAccounts(_ requestProvider: @escaping (Pagination) -> Request<[Account]>,
							  _ completion: @escaping (Swift.Result<[Account], Errors>) -> Void)
	{
		client.runAndAggregateAllPages(requestProvider: requestProvider)
		{
			result in

			switch result
			{
			case .success(let response):
				let accounts = response.value
				completion(.success(accounts))

			case .failure(let error):
				completion(.failure(.networkError(error)))
			}
		}
	}

	enum Errors: Error, UserDescriptionError
	{
		case networkError(Error)
		case persistenceError(Error)

		var userDescription: String
		{
			switch self
			{
			case .networkError(let error): return error.localizedDescription
			case .persistenceError(let error): return error.localizedDescription
			}
		}
	}
}
