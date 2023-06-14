//
//  StatusDisplaying.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 31.12.18.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2018 Bruno Philipe.
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

protocol StatusDisplaying
{
	/// Set the displayed status.
	///
	/// - Parameters:
	///   - displayedStatus: The status to display.
	///   - poll: A poll. Can be used to override the poll in the status object in case it is stale.
	///   - attachmentPresenter: The object that will handle attachment display events.
	///   - interactionHandler: The object that will handle status interaction events.
	///   - activeInstance: The instance where the active user is registered.
	func set(displayedStatus: Status,
			 poll: Poll?,
			 attachmentPresenter: AttachmentPresenting,
			 interactionHandler: StatusInteractionHandling,
			 activeInstance: Instance)

	/// Set whether a poll reload task is active for the associated poll.
	func setHasActivePollTask(_ hasTask: Bool)
}

protocol StatusInteractionHandling: AnyObject
{
	/// The logged-in client from which the interacted status are fetched.
	var client: ClientType? { get }

	/// Interactions cause a fresh sample of a status to be fetched. This is an opportunity for the handler to
	/// update its cache if that's interesting.
	func handle(updatedStatus: Status)

	/// When an interaction fails, this method is called on the handler.
	func handle<T: UserDescriptionError>(interactionError: T)

	/// Tells the handler it should prepare and present a reply composition window for the provided status.
	func reply(to statusID: String)

	/// Tells the handler that the user wants to compose a message by mentioning a specific user.
	func mention(userHandle: String, directMessage: Bool)

	/// Tells the handler the user clicked on the name of a user.
	func show(account: Account)

	/// Tells the handler the user asked for more details on a status to be displayed.
	func show(status: Status)

	/// Tells the handler the user asked for more details on a tag to be displayed.
	func show(tag: Tag)

	/// Tells the handler the user asked for a status' edit history to be displayed.
	func showStatusEdits(status: Status, edits: [StatusEdit])

	/// Asks the handler whether the active account can delete the provided status.
	func canDeleteOrEdit(status: Status) -> Bool

	/// Asks the handler whether the active account can pin/unpin the provided status.
	func canPin(status: Status) -> Bool

	/// Asks the handler to confirm with the user whether a status should be deleted.
	func confirmDelete(status: Status, isRedrafting: Bool, completion: @escaping (Bool) -> Void)

	/// Tells the handler the user wants to re-draft a status.
	func redraft(status: Status)

	/// Tells the handler the user wants to edit a status.
	func edit(status: Status)

	/// Asks the handler to open a URL the user has clicked.
	func handle(linkURL: URL, knownTags: [Tag]?)

	/// Tells the handler the user has voted on one or more options on a poll.
	func voteOn(poll: Poll, statusID: String, options: IndexSet, completion: @escaping (Swift.Result<Poll, Error>) -> Void)

	/// Tells the handler the user has requested the poll data to be reloaded.
	func refreshPoll(statusID: String, pollID: String)

	/// Asks the handler for menu items to diplay for this status, to be displayed in a context menu, for example.
	func menuItems(for status: Status) -> [NSMenuItem]
}

extension StatusInteractionHandling
{
	func favoriteStatus(with statusID: String, completion: @escaping (Bool) -> Void)
	{
		interact(using: Statuses.favourite(id: statusID))
		{
			status in completion((status?.favourited ?? false) == true)
		}
	}

	func unfavoriteStatus(with statusID: String, completion: @escaping (Bool) -> Void)
	{
		interact(using: Statuses.unfavourite(id: statusID))
		{
			status in completion((status?.favourited ?? true) != true)
		}
	}

	func reblogStatus(with statusID: String, completion: @escaping (Bool) -> Void)
	{
		interact(using: Statuses.reblog(id: statusID))
		{
			status in completion((status?.reblogged ?? false) == true)
		}
	}

	func unreblogStatus(with statusID: String, completion: @escaping (Bool) -> Void)
	{
		interact(using: Statuses.unreblog(id: statusID))
		{
			status in completion((status?.reblogged ?? true) != true)
		}
	}

	func bookmarkStatus(with statusID: String, completion: @escaping (Bool) -> Void)
	{
		interact(using: Statuses.bookmark(id: statusID))
		{
			status in completion((status?.bookmarked ?? false) == true)
		}
	}

	func unbookmarkStatus(with statusID: String, completion: @escaping (Bool) -> Void)
	{
		interact(using: Statuses.unbookmark(id: statusID))
		{
			status in completion((status?.bookmarked ?? true) != true)
		}
	}

	func fetchEditHistory(for statusID: String, completion: (([StatusEdit]?) -> Void)? = nil)
	{
		client?.run(Statuses.history(id: statusID))
		{
			[weak self] result in

			switch result
			{
			case .success(let response):
				let statusEdits = response.value
				completion?(statusEdits)

			case .failure(let error):
				completion?(nil)
				DispatchQueue.main.async { self?.handle(interactionError: NetworkError(error)) }
			}
		}
	}

	private func interact(using request: Request<Status>, completion: ((Status?) -> Void)? = nil)
	{
		client?.run(request)
		{
			[weak self] result in

			switch result
			{
			case .success(let response):
				let updatedStatus = response.value
				completion?(updatedStatus)
				DispatchQueue.main.async { self?.handle(updatedStatus: updatedStatus) }

			case .failure(let error):
				completion?(nil)
				DispatchQueue.main.async { self?.handle(interactionError: NetworkError(error)) }
			}
		}
	}

	func delete(status: Status, redraft: Bool)
	{
		confirmDelete(status: status, isRedrafting: redraft)
		{
			[weak self] proceed in

			if proceed
			{
				self?.reallyDelete(status: status, redraft: redraft)
			}
		}
	}

	func reallyDelete(status: Status, redraft: Bool)
	{
		client?.run(Statuses.delete(id: status.id))
		{
			[weak self] result in

			DispatchQueue.main.async
			{
				switch result
				{
				case .failure(let error):
					self?.handle(interactionError: NetworkError(error))

				case .success:
					if redraft
					{
						self?.redraft(status: status)
					}
				}
			}
		}
	}

	func pin(status: Status)
	{
		interact(using: Statuses.pin(id: status.id))
	}

	func unpin(status: Status)
	{
		interact(using: Statuses.unpin(id: status.id))
	}
}
