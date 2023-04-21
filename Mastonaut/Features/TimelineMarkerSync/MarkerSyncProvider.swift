//
//  MarkerSyncProvider.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 14.04.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation
import MastodonKit

/// Implementations are currently expected to only handle the home timeline.
/// The Mastodon API also supports the notifications timeline, but not any
/// other timeline (as of 4.1).

protocol MarkerSyncProvider {
	func read(client: ClientType) async -> Marker?
	
	func write(client: ClientType, newMarker: Marker)
}
