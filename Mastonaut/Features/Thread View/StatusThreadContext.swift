//
//  StatusThreadContext.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 13.06.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation
import MastodonKit

class StatusThreadContext {
	var items = [String: StatusThreadItem]()

	func getItem(status: Status) -> StatusThreadItem? {
		return items[status.uri] ?? nil
	}

	func build(status: Status, descendants: [Status]) {
		items[status.uri] = StatusThreadItem(level: 0) // , deeperDescendants: descendants)

		recursiveAppend(parentID: status.id,
		                level: 1,
						descendants: descendants)
	}

	private func recursiveAppend(parentID: String, level: Int, descendants: [Status]) {
		let children = descendants.filter { $0.inReplyToID == parentID }

		for childStatus in children {
			items[childStatus.uri] = StatusThreadItem(level: level) // , deeperDescendants: <#T##[Status]#>)

			recursiveAppend(parentID: childStatus.id, level: level + 1, descendants: descendants)
		}
	}
}

struct StatusThreadItem {
	let level: Int
//	let deeperDescendants: [Status]
}
