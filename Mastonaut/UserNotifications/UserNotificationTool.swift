//
//  UserNotificationTool.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 12.08.19.
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
import UserNotifications
import MastodonKit
import CoreTootin

class UserNotificationTool
{
	private var postedNotificationsCount: Int = 0
	{
		didSet
		{
			let count = postedNotificationsCount
			NSApp.dockTile.badgeLabel = count == 0 ? nil : "\(count)"
		}
	}

	func postNotification(title: String, subtitle: String?, message: String?, payload: NotificationPayload? = nil)
	{
		let notification = NSUserNotification()
		notification.title = title
		notification.subtitle = subtitle
		notification.informativeText = message
		notification.payload = payload

		NSUserNotificationCenter.default.scheduleNotification(notification)

		if NSApp.isActive == false
		{
			postedNotificationsCount += 1
		}
		else
		{
			postedNotificationsCount = 0
		}
	}

	func postNotification(mastodonEvent notification: MastodonNotification,
						  receiverName: String?,
						  userAccount: UUID,
						  detailMode: AccountPreferences.NotificationDetailMode)
	{
		let showDetails: Bool

		switch detailMode
		{
		case .always: showDetails = true
		case .never: showDetails = false
		case .whenClean: showDetails = notification.isClean
		}

		var actorName: String { return showDetails ? notification.authorName : 🔠("A user") }
		var contentOrSpoiler: NSAttributedString?
		{
			return showDetails ? notification.status?.attributedContent : notification.status?.attributedSpoiler
		}

		let title: String
		let subtitle = receiverName.map { 🔠("For %@", $0) }
		var message: String? = nil

		switch notification.type
		{
		case .mention:
			title = 🔠("%@ mentioned you", actorName)
			message = contentOrSpoiler?.string.ellipsedPrefix(maxLength: 80)
		case .reblog:
			title = 🔠("%@ boosted your toot", actorName)
			message = contentOrSpoiler?.string.ellipsedPrefix(maxLength: 80)
		case .favourite:
			title = 🔠("%@ favorited your toot", actorName)
			message = contentOrSpoiler?.string.ellipsedPrefix(maxLength: 80)
		case .follow:
			title = 🔠("%@ followed you", actorName)
			message = showDetails ? notification.account.attributedNote.string.ellipsedPrefix(maxLength: 80) : nil
		case .follow_request:
			title = 🔠("%@ requested to followed you", actorName)
			message = showDetails ? notification.account.attributedNote.string.ellipsedPrefix(maxLength: 80) : nil
		case .poll:
			title = 🔠("A poll has ended")
			message = contentOrSpoiler?.string.ellipsedPrefix(maxLength: 80)
		default:
			return
		}

		let notificationPayload: NotificationPayload

		if let status = notification.status
		{
			notificationPayload = NotificationPayload(accountUUID: userAccount,
													  referenceURI: status.resolvableURI,
													  referenceType: .status)
		}
		else
		{
			notificationPayload = NotificationPayload(accountUUID: userAccount,
													  referenceURI: notification.account.acct,
													  referenceType: .account)
		}

		postNotification(title: title, subtitle: subtitle, message: message, payload: notificationPayload)
	}

	func resetDockTileBadge()
	{
		postedNotificationsCount = 0
	}
}

extension NSUserNotification
{
	var payload: NotificationPayload?
	{
		set(payload)
		{
			var dict = userInfo ?? [:]

			if let payload = payload
			{
				dict["mastonaut_payload"] = [
					"account_UUID": payload.accountUUID.uuidString,
					"reference_URI": payload.referenceURI,
					"reference_type": payload.referenceType.rawValue
				]
			}
			else
			{
				dict["mastonaut_payload"] = nil
			}

			userInfo = dict
		}

		get
		{
			guard
				let dict = userInfo?["mastonaut_payload"] as? [String: Any?],
				let accountUUID = (dict["account_UUID"] as? String).flatMap({ UUID(uuidString: $0) }),
				let referenceURI = dict["reference_URI"] as? String,
				let referenceType = (dict["reference_type"] as? String).flatMap({ NotificationPayload.Reference(rawValue: $0) })
			else { return nil }

			return NotificationPayload(accountUUID: accountUUID, referenceURI: referenceURI, referenceType: referenceType)
		}
	}
}

struct NotificationPayload
{
	let accountUUID: UUID
	let referenceURI: String
	let referenceType: Reference

	enum Reference: String
	{
		case account
		case status
	}
}
