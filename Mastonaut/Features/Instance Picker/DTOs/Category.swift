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
	
	// TODO: change order so that general and regional show closer to top
	// TODO: maybe add separators?

	public var symbolName: String? {
		switch category {
		case "general":
			return nil
		case "regional":
			return "globe.europe.africa.fill"

		case "academia":
			return "books.vertical.fill"
		case "activism":
			return "figure.wave.circle.fill"
		case "art":
			return "theatermask.and.paintbrush.fill"
		case "books":
			return "text.book.closed.fill"
		case "food":
			return "fork.knife"
		case "furry":
			return "pawprint.fill"
		case "games":
			return "gamecontroller.fill"
		case "hobby":
			return "figure.martial.arts"
		case "journalism":
			return "newspaper.fill"
		case "lgbt":
			return "sparkles"
		case "music":
			return "music.note"
		case "religion":
			return "person.line.dotted.person.fill"
		case "sports":
			return "sportscourt.fill"
		case "tech":
			return "desktopcomputer"
		default:
			return nil
		}
	}

	public let category: String
	public let serversCount: Int

	private enum CodingKeys: String, CodingKey {
		case category
		case serversCount = "servers_count"
	}
}
