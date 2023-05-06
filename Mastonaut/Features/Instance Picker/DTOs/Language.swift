//
//  Language.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 06.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

struct Language : Codable {
	public let locale:String
	public let language:String?
	public let serversCount: Int
	
	private enum CodingKeys:String,CodingKey {
		case locale
		case language
		case serversCount = "servers_count"
	}
}
