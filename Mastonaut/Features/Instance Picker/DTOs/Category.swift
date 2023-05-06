//
//  Category.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 06.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

struct Category: Codable {
	// TODO: add displayName property that isn't all-lowercase
	// (and special-case LGBT so it is all-uppercase)

	public let category: String
	public let serversCount: Int

	private enum CodingKeys: String, CodingKey {
		case category
		case serversCount = "servers_count"
	}
}
