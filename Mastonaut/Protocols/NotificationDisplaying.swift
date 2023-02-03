//
//  NotificationDisplaying.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 26.01.19.
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

protocol NotificationDisplaying
{
	var displayedNotificationId: String? { get }

	var displayedStatusId: String? { get }

	func set(displayedNotification: CoalescedNotification,
			 attachmentPresenter: AttachmentPresenting,
			 interactionHandler: NotificationInteractionHandling,
			 activeInstance: Instance)
}

protocol NotificationInteractionHandling: AnyObject//, AttributedLabelLinkHandler
{
	/// The logged-in client from which the interacted status are fetched.
	var client: ClientType? { get }

	/// Tells the handler it should prepare and present a reply composition window for the provided status.
	func reply(to statusID: String)

	/// When an interaction fails, this method is called on the handler.
	func handle<T: UserDescriptionError>(interactionError: T)

	/// Tells the handler the user clicked on the name of a user.
	func show(account: Account)

	/// Asks the handler to open a URL the user has clicked.
	func handle(linkURL: URL, knownTags: [Tag]?)
}

extension NotificationInteractionHandling
{
	func favoriteStatus(for notificationDisplay: NotificationDisplaying, completion: @escaping (Bool) -> Void)
	{
		guard let statusID = notificationDisplay.displayedStatusId else { return }
		interact(using: Statuses.favourite(id: statusID))
		{
			status in completion((status?.favourited ?? false) == true)
		}
	}

	func unfavoriteStatus(for notificationDisplay: NotificationDisplaying, completion: @escaping (Bool) -> Void)
	{
		guard let statusID = notificationDisplay.displayedStatusId else { return }
		interact(using: Statuses.unfavourite(id: statusID))
		{
			status in completion((status?.favourited ?? true) != true)
		}
	}

	func reblogStatus(for notificationDisplay: NotificationDisplaying, completion: @escaping (Bool) -> Void)
	{
		guard let statusID = notificationDisplay.displayedStatusId else { return }
		interact(using: Statuses.reblog(id: statusID))
		{
			status in completion((status?.reblogged ?? false) == true)
		}
	}

	func unreblogStatus(for notificationDisplay: NotificationDisplaying, completion: @escaping (Bool) -> Void)
	{
		guard let statusID = notificationDisplay.displayedStatusId else { return }
		interact(using: Statuses.unreblog(id: statusID))
		{
			status in completion((status?.reblogged ?? true) != true)
		}
	}

	private func interact<T>(using request: Request<T>, completion: @escaping (T?) -> Void)
	{
		client?.run(request)
		{
			[weak self] result in

			switch result
			{
			case .success(let updatedStatus, _):
				completion(updatedStatus)

			case .failure(let error):
				completion(nil)
				self?.handle(interactionError: NetworkError(error))
			}
		}
	}
}
