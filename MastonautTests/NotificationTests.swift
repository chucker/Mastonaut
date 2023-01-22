//
//  NotificationTests.swift
//  MastonautTests
//
//  Created by Sören Kuklau on 21.01.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

import CoreTootin
import MastodonKit
@testable import Mastonaut
import XCTest

enum FixtureError: Error {
	case invalidPath, invalidData
}

enum Fixture {
	static func load(fileName: String) throws -> Data {
		var testsDirectory = URL(fileURLWithPath: #file, isDirectory: false)
		testsDirectory.deleteLastPathComponent()

		guard let filePath = URL(string: fileName, relativeTo: testsDirectory) else {
			throw FixtureError.invalidPath
		}

		guard let jsonData = try? Data(contentsOf: filePath) else {
			throw FixtureError.invalidData
		}

		return jsonData
	}
}

///
/// **Note:** These tests will fail if you have 'coalesce notifications' disabled.
/// Ideally, we would have something like MockPreferences here.
///
class NotificationTests: XCTestCase {
	func testCoalesceJustOneShouldBeLeftAlone() {
		let decoder = JSONDecoder()

		let data = try! Fixture.load(fileName: "NotificationFixtures/CoalesceJustOne.json")
		let notifications = try! decoder.decode([MastodonNotification].self, from: data)

		XCTAssertEqual(notifications.count, 1)

		let coalescedNotifications = UserNotificationAgent.coalesceNotifications(notifications)

		XCTAssertEqual(coalescedNotifications.count, notifications.count)
	}
	
	func testCoalesceDifferentStatusesShouldBeLeftAlone() {
		let decoder = JSONDecoder()

		let data = try! Fixture.load(fileName: "NotificationFixtures/CoalesceDifferentStatuses.json")
		let notifications = try! decoder.decode([MastodonNotification].self, from: data)

		XCTAssertEqual(notifications.count, 2)

		let coalescedNotifications = UserNotificationAgent.coalesceNotifications(notifications)

		XCTAssertEqual(coalescedNotifications.count, notifications.count)
	}
	
	func testCoalesceSameConsecutiveStatusesShouldBeMerged() {
		let decoder = JSONDecoder()

		let data = try! Fixture.load(fileName: "NotificationFixtures/CoalesceSameConsecutiveStatus.json")
		let notifications = try! decoder.decode([MastodonNotification].self, from: data)

		XCTAssertEqual(notifications.count, 4)

		let coalescedNotifications = UserNotificationAgent.coalesceNotifications(notifications)

		XCTAssertEqual(coalescedNotifications.count, 2)
	}
	
	func testCoalesceFollowShouldBeMerged() {
		let decoder = JSONDecoder()

		let data = try! Fixture.load(fileName: "NotificationFixtures/CoalesceFollow.json")
		let notifications = try! decoder.decode([MastodonNotification].self, from: data)

		XCTAssertEqual(notifications.count, 2)

		let coalescedNotifications = UserNotificationAgent.coalesceNotifications(notifications)

		XCTAssertEqual(coalescedNotifications.count, 1)
	}
}
