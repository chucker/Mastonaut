//
//  RelationshipSet.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 07.04.19.
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

struct RelationshipSet: OptionSet
{
	let rawValue: Int16

	static let follower = RelationshipSet(rawValue: 1 << 0)
	static let following = RelationshipSet(rawValue: 1 << 1)
	static let followingRequested = RelationshipSet(rawValue: 1 << 8)
	static let muted = RelationshipSet(rawValue: 1 << 2)
	static let blocked = RelationshipSet(rawValue: 1 << 3)

	static let isAuthor = RelationshipSet(rawValue: 1 << 6)
	static let isSelf = RelationshipSet(rawValue: 1 << 7)
}
