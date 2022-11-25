//
//  FollowedList.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 30.10.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import Foundation
import MastodonKit
import CoreTootin

extension FollowedList
{
	static func fetchOrInsert(for list: List, authorizedAccount: AuthorizedAccount) throws -> FollowedList
	{
		let context = AppDelegate.shared.managedObjectContext
		let fetchRequest = self.fetchRequest(id: list.id, authorizedAccount: authorizedAccount)

		let followedList = try context.fetch(fetchRequest).first ?? insert(id: list.id)
		followedList.title = list.title

		return followedList
	}
	
	fileprivate static func fetchRequest(id: String, authorizedAccount: AuthorizedAccount) -> NSFetchRequest<FollowedList>
	{
		let fetchRequest: NSFetchRequest<FollowedList> = self.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
											 "id", id,
											 "authorizedAccount", authorizedAccount.objectID)
		return fetchRequest
	}
	
	fileprivate static func insert(id: String) -> FollowedList
	{
		let blank = FollowedList(context: AppDelegate.shared.managedObjectContext)
		blank.id = id
		return blank
	}
}
