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
	case following(accounts: [Account])

	/// One or more accounts reblogging and/or favoriting a single status.
	case rebloggedOrFavorited(accounts: [Account], types: [NotificationType], status: Status)
}
