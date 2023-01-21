//
//  UserNotificationAgent.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 24.08.19.
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

extension Foundation.Notification.Name
{
	static var contextObjectsDidChange: Foundation.Notification.Name
	{
		return Notification.Name.NSManagedObjectContextObjectsDidChange
	}
}

class UserNotificationAgent
{
	let notificationTool = UserNotificationTool()

	private unowned let accountService = AppDelegate.shared.accountsService
	private unowned let context = AppDelegate.shared.managedObjectContext

	private var observations: [NSKeyValueObservation] = []
	private var coreDataObserver: NSObjectProtocol?

	private var accountReceiverMap: [String: (receiver: ConcreteRemoteEventsReceiver, reference: ReceiverRef)] = [:]
	private var remoteEventsCoordinator: RemoteEventsCoordinator { return .shared }

	func setUp()
	{
		observations.observe(accountService, \.authorizedAccountsCount)
		{
			[weak self] _, _ in DispatchQueue.main.async { self?.updateActiveEventReceivers() }
		}

		coreDataObserver = NotificationCenter.observer(for: .contextObjectsDidChange)
		{
			[weak self] notification in

			guard notification.hasChangedObjects(ofType: AccountPreferences.self) else { return }

			DispatchQueue.main.async { self?.updateActiveEventReceivers() }
		}

		updateActiveEventReceivers()
	}

	private func updateActiveEventReceivers()
	{
		for account in accountService.authorizedAccounts
		{
			if account.preferences(context: context).notificationDisplayMode == .always
			{
				addOrUpdateReceiver(for: account)
			}
			else
			{
				removeReceiver(for: account)
			}
		}
	}

	private func addOrUpdateReceiver(for account: AuthorizedAccount)
	{
		let uuid = account.uuid.uuidString

		if let receiver = accountReceiverMap[uuid]?.receiver
		{
			receiver.mode = account.preferences(context: context).notificationDetailMode
		}
		else if
			let client = Client.create(for: account),
			let accessToken = client.accessToken,
			let baseURL = client.parsedBaseUrl
		{
			let receiver = ConcreteRemoteEventsReceiver(mode: account.preferences(context: context).notificationDetailMode)
			let reference = remoteEventsCoordinator.add(receiver: receiver, for: .init(baseURL: baseURL,
			                                                                           accessToken: accessToken,
			                                                                           stream: .user))

			accountReceiverMap[uuid] = (receiver, reference)

			let uuid = account.uuid
			let acountURI = account.uri!

			receiver.eventReceivedHandler =
			{
				[weak self] event, detailMode in

				guard case .notification(let notification) = event else { return }

				self?.postNotification(for: uuid,
				                       account: account,
				                       receiverName: acountURI,
				                       notification: notification,
				                       detailMode: detailMode)
			}

			receiver.didDisconnectHandler =
			{
				[weak self] in

				guard
					let self = self,
					let reference = self.accountReceiverMap[uuid.uuidString]?.reference
				else { return }

				self.remoteEventsCoordinator.reconnectListener(for: reference)
			}
		}
	}

	public static func shouldShowNotification(_ notification: MastodonNotification, accountNotificationPreferences: AccountNotificationPreferences?) -> Bool
	{
		(notification.type == .mention && accountNotificationPreferences?.showMentions ?? true) ||
			(notification.type == .status && accountNotificationPreferences?.showStatuses ?? true) ||

			(notification.type == .follow && accountNotificationPreferences?.showNewFollowers ?? true) ||
			(notification.type == .follow_request && accountNotificationPreferences?.showFollowRequests ?? true) ||

			(notification.type == .reblog && accountNotificationPreferences?.showBoosts ?? true) ||
			(notification.type == .favourite && accountNotificationPreferences?.showFavorites ?? true) ||

			(notification.type == .poll && accountNotificationPreferences?.showPollResults ?? true) ||

			(notification.type == .update && accountNotificationPreferences?.showEdits ?? true) ||

			(notification.type == .admin_sign_up && accountNotificationPreferences?.showAdminSignUps ?? true) ||
			(notification.type == .admin_report && accountNotificationPreferences?.showAdminReports ?? true)
	}

	public static func coalesceNotifications(_ notifications: [MastodonNotification]) -> [MastodonNotification]
	{
		let preferences = MastonautPreferences.instance

		if !preferences.coalesceNotifications
		{
			return notifications
		}

		for i in 1 ... notifications.count - 1
		{
			let previous = notifications[i - 1]
			let current = notifications[i]

			if previous.type == .follow && current.type == .follow
			{
				
			}
		}

		return notifications
	}

	private func postNotification(for accountUUID: UUID,
	                              account: AuthorizedAccount,
	                              receiverName: String?,
	                              notification: MastodonNotification,
	                              detailMode: AccountPreferences.NotificationDetailMode)
	{
		let accountNotificationPreferences = account.notificationPreferences(context: AppDelegate.shared.managedObjectContext)

		if !UserNotificationAgent.shouldShowNotification(notification,
		                                                 accountNotificationPreferences: accountNotificationPreferences)
		{ return }

		notificationTool.postNotification(mastodonEvent: notification,
		                                  receiverName: receiverName,
		                                  userAccount: accountUUID,
		                                  detailMode: detailMode)
	}

	private func removeReceiver(for account: AuthorizedAccount)
	{
		guard let reference = accountReceiverMap[account.uuid.uuidString]?.reference else { return }

		remoteEventsCoordinator.remove(receiver: reference)
		accountReceiverMap.removeValue(forKey: account.uuid.uuidString)
	}
}

private class ConcreteRemoteEventsReceiver: NSObject, RemoteEventsReceiver
{
	var mode: AccountPreferences.NotificationDetailMode

	var eventReceivedHandler: ((ClientEvent, AccountPreferences.NotificationDetailMode) -> Void)?
	var didConnectHandler: (() -> Void)?
	var didDisconnectHandler: (() -> Void)?

	deinit
	{
		NSLog("Releasing event receiver: \(self)")
	}

	internal init(mode: AccountPreferences.NotificationDetailMode)
	{
		self.mode = mode
	}

	func remoteEventsCoordinator(streamIdentifier: StreamIdentifier, didHandleEvent event: ClientEvent)
	{
		eventReceivedHandler?(event, mode)
	}

	func remoteEventsCoordinator(streamIdentifierDidConnect: StreamIdentifier)
	{
		didConnectHandler?()
	}

	func remoteEventsCoordinator(streamIdentifierDidDisconnect: StreamIdentifier)
	{
		didDisconnectHandler?()
	}

	func remoteEventsCoordinator(streamIdentifier: StreamIdentifier, parserProducedError error: Error) {}
}

private extension Foundation.Notification
{
	func hasChangedObjects<T: NSManagedObject>(ofType: T.Type) -> Bool
	{
		return (userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>)?.first(where: { $0 is T }) != nil
	}
}
