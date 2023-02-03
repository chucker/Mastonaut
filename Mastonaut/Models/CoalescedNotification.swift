//
//  CoalescedNotification.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 21.01.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation
import MastodonKit

public enum CoalescedNotification {
	/// A notification that hasn't been coalesced. Either
	/// coalescing is disabled, or the notification type
	/// doesn't support it.
	case uncoalesced(originalNotification: MastodonKit.Notification)

	/// One or more accounts following the authorized account.
	case following(accounts: [Account], newestNotification: MastodonKit.Notification)

	/// One or more accounts reblogging and/or favoriting a single status.
	case rebloggedOrFavorited(accounts: [Account], types: [NotificationType], status: Status,
	                          newestNotification: MastodonKit.Notification)

	var status: Status? {
		switch self {
		case .uncoalesced(let originalNotification):
			return originalNotification.status
		case .following:
			return nil
		case .rebloggedOrFavorited(_, _, _, let newestNotification):
			return newestNotification.status
		}
	}

	var isOfKnownType: Bool {
		switch self {
		case .uncoalesced(let originalNotification):
			return originalNotification.isOfKnownType
		default: // if we wrap it, obviously we know and support the type
			return true
		}
	}
}

extension CoalescedNotification: ListViewPresentable {
	var key: String {
		switch self {
		case .uncoalesced(let originalNotification):
			return originalNotification.id
		case .following(_, let newestNotification):
			return newestNotification.id
		case .rebloggedOrFavorited(_, _, _, let newestNotification):
			return newestNotification.id
		}
	}
}

extension CoalescedNotification: Codable {}
