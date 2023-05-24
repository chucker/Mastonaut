//
//  NotificationsPreferencesViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 21.08.19.
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
import CoreTootin

class NotificationsPreferencesViewController: BaseAccountsPreferencesViewController
{
	@IBOutlet private weak var perAccountNotificationPreferencesView: NSView!

	@objc dynamic private var accountPreferences: AccountPreferences?
	@objc dynamic private var accountNotificationPreferences: AccountNotificationPreferences?

	private var accountCountObserver: NSKeyValueObservation?
	private var preferenceObservers: [AnyObject] = []

	override func viewDidLoad() {
		super.viewDidLoad()
		
		accountCountObserver = AppDelegate.shared.accountsService.observe(\.authorizedAccountsCount)
			{
				[weak self] (service, _) in
				self?.tableView.deselectAll(nil)
				self?.accountPreferences = nil
				self?.accounts = service.authorizedAccounts
			}
	}

	override func viewWillDisappear()
	{
		super.viewWillDisappear()

		AppDelegate.shared.saveContext()
	}

	// MARK: - Table View Delegate

	func tableViewSelectionDidChange(_ notification: Foundation.Notification)
	{
		let row = tableView.selectedRow

		guard row >= 0 else
		{
			accountPreferences = nil
			accountNotificationPreferences = nil
			return
		}

		accountPreferences = accounts?[row].preferences(context: AppDelegate.shared.managedObjectContext)
		accountNotificationPreferences = accounts?[row].notificationPreferences(context: AppDelegate.shared.managedObjectContext)

		if accountPreferences != nil && accountNotificationPreferences != nil
		{
			if #available(macOS 11.0, *)
			{
				let view = NotificationPerAccountPreferencesView(accountPreferences: accountPreferences,
				                                                 accountNotificationPreferences: accountNotificationPreferences,
				                                                 notificationDisplayMode: accountPreferences?.notificationDisplayMode ?? .always,
				                                                 notificationDetailMode: accountPreferences?.notificationDetailMode ?? .always)

				AppKitSwiftUIIntegration.hostSwiftUIView(view, inView: perAccountNotificationPreferencesView)
			}
		}
	}
}
