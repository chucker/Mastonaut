//
//  Server.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 07.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

struct Server: Codable {
	public let domain: String
	public let version: String
	public let description: String
	public let languages: [String]
	public let region: String
	public let categories: [String]
	public let proxiedThumbnail: String
	public let blurhash: String?
	public let totalUsers: Int
	public let lastWeekUsers: Int
	public let approvalRequired: Bool
//	public let language:String
//	public let category:String

	private enum CodingKeys: String, CodingKey {
		case domain
		case version
		case description
		case languages
		case region
		case categories
		case proxiedThumbnail="proxied_thumbnail"
		case blurhash
		case totalUsers="total_users"
		case lastWeekUsers="last_week_users"
		case approvalRequired="approval_required"
	}
}
