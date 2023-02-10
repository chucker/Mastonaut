//
//  Stats_StatusesPerHour+Helpers.swift
//  CoreTootin
//
//  Created by Sören Kuklau on 09.02.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import CoreData
import Foundation
import MastodonKit

public extension Stats_StatusesByHour {
	static func insert(context: NSManagedObjectContext, status: Status) {
		let request = NSFetchRequest<Stats_StatusesByHour>(entityName: "Stats_StatusesByHour")
		let usernamePredicate = NSPredicate(format: "username = %@", status.account.username),
		    statusPredicate = NSPredicate(format: "statusID = %@", status.id)
		request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [usernamePredicate, statusPredicate])
		request.fetchLimit = 1

		let calendar = Calendar.current
		
		if let result = try? context.fetch(request), result.count > 0 {
		} else {
			let newRow = Stats_StatusesByHour(context: context)
			newRow.username = status.account.username
			newRow.timestamp = status.createdAt
			newRow.hourOfDay = Int16(calendar.component(.hour, from: status.createdAt))
			newRow.dayOfWeek = Int16(calendar.component(.weekday, from: status.createdAt))
			newRow.statusID = status.id
			newRow.isReblog = status.reblog != nil
		}
	}
	
	static func getCountsByHourOfDay(context: NSManagedObjectContext, forUsername: String?) -> [AggregateStatusResult] {
		let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Stats_StatusesByHour")
		
		let expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "statusID")])
		let expressionDescription = NSExpressionDescription()
		expressionDescription.name = "countStatuses"
		expressionDescription.expression = expression
		expressionDescription.resultType = .integer64
		
		let calendar = Calendar.current
		
		request.predicate = NSPredicate(format: "timestamp > %@", calendar.date(byAdding: .day, value: -7, to: Date.now)! as NSDate)
		request.returnsObjectsAsFaults = false
		
		if forUsername != nil {
			request.propertiesToGroupBy = ["hourOfDay", "isReblog", "username"]
			request.propertiesToFetch = ["hourOfDay", "isReblog", "username", expressionDescription]
		} else {
			request.propertiesToGroupBy = ["hourOfDay", "isReblog"]
			request.propertiesToFetch = ["hourOfDay", "isReblog", expressionDescription]
		}
		
		request.resultType = .dictionaryResultType
		
		var stats = [AggregateStatusResult]()
		
		for _ in 0 ... 23 {
			stats.append(AggregateStatusResult(postCount: 0, boostCount: 0, postCountSelectedUser: 0, boostCountSelectedUser: 0))
		}
		
		if let result = try? context.fetch(request) {
			for item in result {
				if let dict = item as? NSDictionary,
				   let hour = dict.value(forKey: "hourOfDay") as? Int,
				   let isReblog = dict.value(forKey: "isReblog") as? Bool,
				   let count = dict.value(forKey: "countStatuses") as? Int
				{
					if let username = dict.value(forKey: "username") as? String, username == forUsername {
						if !isReblog {
							stats[hour].postCountSelectedUser = count
						} else {
							stats[hour].boostCountSelectedUser = count
						}
					} else {
						if !isReblog {
							stats[hour].postCount = count
						} else {
							stats[hour].boostCount = count
						}
					}
				}
			}
		}
		
		return stats
	}
	
	static func getCountsByDayOfWeek(context: NSManagedObjectContext) -> [AggregateStatusResult] {
		let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Stats_StatusesByHour")
		
		let expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "statusID")])
		let expressionDescription = NSExpressionDescription()
		expressionDescription.name = "countStatuses"
		expressionDescription.expression = expression
		expressionDescription.resultType = .integer64
		
		let calendar = Calendar.current
		
		request.predicate = NSPredicate(format: "timestamp > %@", calendar.date(byAdding: .day, value: -7, to: Date.now)! as NSDate)
		request.returnsObjectsAsFaults = false
		request.propertiesToGroupBy = ["dayOfWeek", "isReblog"]
		request.propertiesToFetch = ["dayOfWeek", "isReblog", expressionDescription]
		request.resultType = .dictionaryResultType
		
		var stats = [AggregateStatusResult]()
		
		for _ in 0 ... 6 {
			stats.append(AggregateStatusResult(postCount: 0, boostCount: 0, postCountSelectedUser: 0, boostCountSelectedUser: 0))
		}
		
		if let result = try? context.fetch(request) {
			for item in result {
				if let dict = item as? NSDictionary,
				   let day = dict.value(forKey: "dayOfWeek") as? Int,
				   let isReblog = dict.value(forKey: "isReblog") as? Bool,
				   let count = dict.value(forKey: "countStatuses") as? Int
				{
					if !isReblog {
						stats[day].postCount = count
					} else {
						stats[day].boostCount = count
					}
				}
			}
		}
		
		return stats
	}
	
	struct AggregateStatusResult {
		public var postCount: Int
		public var boostCount: Int

		public var postCountSelectedUser: Int
		public var boostCountSelectedUser: Int
	}
}
