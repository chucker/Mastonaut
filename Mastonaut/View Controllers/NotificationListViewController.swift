//
//  NotificationListViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 26.01.19.
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

import Cocoa
import CoreTootin
import MastodonKit

class NotificationListViewController: ListViewController<MastodonNotification>, NotificationInteractionHandling, StatusInteractionHandling, PollVotingCapable, FilterServiceObserver
{
	private var statusIdNotificationIdMap: [String: String] = [:]
	private var observations: [NSKeyValueObservation] = []
	private var reduceMotionNotificationObserver: NSObjectProtocol?
	private var filterService: FilterService?

	private var accountNotificationPreferences: AccountNotificationPreferences?

	internal var updatedPolls: [String: Poll] = [:]
	internal var pollRefreshTimers: [String: Timer] = [:]

	private unowned let context = AppDelegate.shared.managedObjectContext

	private lazy var cellMenuItemHandler: CellMenuItemHandler = .init(tableView: tableView, interactionHandler: self)

	override var nibName: NSNib.Name?
	{
		return "ListViewController"
	}

	deinit
	{
		if let observer = reduceMotionNotificationObserver
		{
			NSWorkspace.shared.notificationCenter.removeObserver(observer)
		}
	}

	override func awakeFromNib()
	{
		super.awakeFromNib()

		observations.observePreference(\MastonautPreferences.mediaDisplayMode)
		{
			[unowned self] _, _ in self.refreshVisibleCellViews()
		}

		observations.observePreference(\MastonautPreferences.spoilerDisplayMode)
		{
			[unowned self] _, _ in self.refreshVisibleCellViews()
		}

		reduceMotionNotificationObserver = NSAccessibility.observeReduceMotionPreference
		{
			[unowned self] in self.refreshVisibleCellViews()
		}
	}

	override func registerCells()
	{
		super.registerCells()

		tableView.register(NSNib(nibNamed: "StatusTableCellView", bundle: .main),
		                   forIdentifier: CellViewIdentifier.status)
		tableView.register(NSNib(nibNamed: "InteractionCellView", bundle: .main),
		                   forIdentifier: CellViewIdentifier.interaction)
		tableView.register(NSNib(nibNamed: "FollowCellView", bundle: .main),
		                   forIdentifier: CellViewIdentifier.follow)
	}

	override func viewDidLoad()
	{
		super.viewDidLoad()

		tableView.setAccessibilityLabel("Notifications")
	}

	override func clientDidChange(_ client: ClientType?, oldClient: ClientType?)
	{
		super.clientDidChange(client, oldClient: oldClient)

		setClientEventStream(.user)

		guard let account = authorizedAccountProvider?.currentAccount else { return }

		filterService = FilterService.service(for: account)
		filterService?.register(observer: self)

		accountNotificationPreferences = account.notificationPreferences(context: AppDelegate.shared.managedObjectContext)
	}

	func handle(updatedStatus: Status)
	{
		// TODO: Maybe we don't have to do anything here?
	}

	func handle(linkURL: URL, knownTags: [Tag]?)
	{
		authorizedAccountProvider?.handle(linkURL: linkURL, knownTags: knownTags)
	}

	func set(hasActivePollTask: Bool, for statusID: String)
	{
		guard
			let index = entryList.firstIndex(where: { $0.entryKey == statusID }),
			let cell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? InteractionCellView
		else
		{
			return
		}

		cell.setHasActivePollTask(hasActivePollTask)
	}

	func handle(updatedPoll poll: Poll, statusID: String)
	{
		guard
			let notificationId = statusIdNotificationIdMap[statusID],
			let index = entryList.firstIndex(where: { $0.entryKey == notificationId })
		else
		{
			return
		}

		// We update the poll even if we don't update the table cell view, because it might just be out of the visible
		// range.
		updatedPolls[poll.id] = poll

		guard
			let cell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? InteractionCellView
		else
		{
			return
		}

		cell.set(updatedPoll: poll)
	}

	func handle<T: UserDescriptionError>(interactionError error: T)
	{
		DispatchQueue.main.async
		{
			[weak self] in self?.view.window?.windowController?.displayError(error,
			                                                                 title: 🔠("interaction.notification"))
		}
	}

	func reply(to statusID: String)
	{
		if let notificationId = statusIdNotificationIdMap[statusID], let status = entry(for: notificationId)?.status
		{
			authorizedAccountProvider?.composeReply(for: status, sender: nil)
		}
	}

	func mention(userHandle: String, directMessage: Bool)
	{
		authorizedAccountProvider?.composeMention(userHandle: userHandle, directMessage: directMessage)
	}

	func show(account: Account)
	{
		guard let instance = authorizedAccountProvider?.currentInstance else { return }
		let profileModel = SidebarMode.profile(uri: account.uri(in: instance), account: account)
		authorizedAccountProvider?.presentInSidebar(profileModel)
	}

	func show(status: Status)
	{
		authorizedAccountProvider?.presentInSidebar(SidebarMode.status(uri: status.resolvableURI, status: status))
	}

	func show(tag: Tag)
	{
		authorizedAccountProvider?.presentInSidebar(SidebarMode.tag(tag.name))
	}
	
	func showStatusEdits(status: MastodonKit.Status, edits: [StatusEdit]) {
		authorizedAccountProvider?.presentInSidebar(SidebarMode.edits(status: status, edits: edits))
	}
	
	func canDeleteOrEdit(status: Status) -> Bool
	{
		return currentUserIsAuthor(of: status)
	}

	func canPin(status: Status) -> Bool
	{
		return currentUserIsAuthor(of: status)
	}

	func confirmDelete(status: Status, isRedrafting: Bool, completion: @escaping (Bool) -> Void)
	{
		let message: String = isRedrafting ? "The contents of this toot will be copied over to the composer, and you'll be able to make changes to it before re-submitting it." : "This action can not be undone."

		let dialogMode: DialogMode = isRedrafting ? .custom(proceed: "Delete and Redraft", dismiss: "Cancel")
			: .custom(proceed: "Delete Toot", dismiss: "Cancel")

		view.window?.windowController?.showAlert(style: .informational,
		                                         title: "Are you sure you want to delete this toot?",
		                                         message: message,
		                                         dialogMode: dialogMode)
		{
			response in
			completion(response == .alertFirstButtonReturn)
		}
	}

	func redraft(status: Status)
	{
		authorizedAccountProvider?.redraft(status: status)
	}
	
	func edit(status: Status)
	{
		authorizedAccountProvider?.edit(status: status)
	}

	override func menuItems(for entryReference: EntryReference) -> [NSMenuItem]
	{
		guard let notification = entry(for: entryReference) else { return [] }
		return menuItems(for: notification)
	}

	func menuItems(for notification: MastodonNotification) -> [NSMenuItem]
	{
		if let status = notification.status
		{
			return menuItems(for: status)
		}
		else
		{
			return NotificationMenuItemsController.shared.menuItems(for: notification, interactionHandler: self)
		}
	}

	func menuItems(for status: Status) -> [NSMenuItem]
	{
		if let notification = statusIdNotificationIdMap[status.id].flatMap({ entryMap[$0] }),
		   entryMatchesAnyFilter(notification)
		{
			return StatusMenuItemsController.shared.menuItems(forFilteredStatus: status, interactionHandler: self)
		}
		else
		{
			return StatusMenuItemsController.shared.menuItems(for: status, interactionHandler: self)
		}
	}

	override func fetchEntries(for insertion: ListViewController<MastodonNotification>.InsertionPoint)
	{
		super.fetchEntries(for: insertion)

		run(request: Notifications.all(range: rangeForEntryFetch(for: insertion)), for: insertion)
	}

	override func prepareNewEntries(_ notifications: [MastodonNotification],
	                                for insertion: ListViewController<MastodonNotification>.InsertionPoint,
	                                pagination: Pagination?)
	{
		var filteredNotifications = notifications.filter { $0.isOfKnownType }

		for notification in filteredNotifications
		{
			if let statusID = notification.status?.id
			{
				statusIdNotificationIdMap[statusID] = notification.id
			}
		}

		filteredNotifications = filteredNotifications.filter { UserNotificationAgent.shouldShowNotification($0, accountNotificationPreferences: accountNotificationPreferences) }

		super.prepareNewEntries(filteredNotifications, for: insertion, pagination: pagination)
	}

	override func cellViewIdentifier(for notification: MastodonNotification) -> NSUserInterfaceItemIdentifier
	{
		switch notification.type
		{
		case .mention:
			return NotificationListViewController.CellViewIdentifier.status

		case .favourite, .reblog, .poll:
			return NotificationListViewController.CellViewIdentifier.interaction

		case .follow, .follow_request:
			return NotificationListViewController.CellViewIdentifier.follow

		default:
			return NSUserInterfaceItemIdentifier("")
			fatalError("Unknown notification types should be filtered!")
		}
	}

	override func populate(cell: NSTableCellView, for notification: MastodonNotification)
	{
		guard
			let attachmentPresenter = authorizedAccountProvider?.attachmentPresenter,
			let instance = authorizedAccountProvider?.currentInstance
		else
		{
			return
		}

		switch notification.type
		{
		case .mention:
			guard let status = notification.status, let statusCell = cell as? StatusDisplaying
			else
			{
				return
			}

			if let poll = status.poll
			{
				setupRefreshTimer(for: poll, statusID: status.id)
			}

			statusCell.set(displayedStatus: status,
			               poll: status.poll.flatMap { updatedPolls[$0.id] },
			               attachmentPresenter: attachmentPresenter,
			               interactionHandler: self,
			               activeInstance: instance)

		case .favourite, .follow, .follow_request, .reblog, .poll:
			guard let notificationCell = cell as? NotificationDisplaying
			else
			{
				return
			}

			notificationCell.set(displayedNotification: notification,
			                     attachmentPresenter: attachmentPresenter,
			                     interactionHandler: self,
			                     activeInstance: instance)

		default:
			break
		}
	}

	override func prepareToDisplay(cellView: NSTableCellView, at row: Int)
	{
		super.prepareToDisplay(cellView: cellView, at: row)

		if let interactionCellView = cellView as? InteractionCellView
		{
			if interactionCellView.displayedNotificationId == nil
			{
				return
			}
		}

		if let window = view.window, let statusCellView = cellView as? StatusTableCellView
		{
			statusCellView.updateContentsVisibility()

			let shouldAnimate = !NSAccessibility.shouldReduceMotion && window.occlusionState.contains(.visible)
			statusCellView.set(shouldDisplayAnimatedContents: shouldAnimate)
		}
	}

	override func receivedClientEvent(_ event: ClientEvent)
	{
		switch event
		{
		case .notification(let notification):
			DispatchQueue.main.async
			{
				[weak self] in

				self?.prepareNewEntries([notification], for: .above, pagination: nil)
				self?.postNotificationIfAppropriate(notification)
			}

		case .delete(let statusID):
			DispatchQueue.main.async
			{
				[weak self] in

				if let notificationId = self?.statusIdNotificationIdMap[statusID]
				{
					self?.handle(deletedEntry: notificationId)
				}
			}

		case .update:
			break

		case .keywordFiltersChanged:
			break
		}
	}

	override func didDoubleClickRow(for notification: MastodonNotification)
	{
		if let status = notification.status
		{
			show(status: status)
		}
		else
		{
			show(account: notification.account)
		}
	}

	private func postNotificationIfAppropriate(_ notification: MastodonNotification)
	{
		guard
			let account = authorizedAccountProvider?.currentAccount,
			account.preferences(context: context).notificationDisplayMode == .whenActive,
			UserNotificationAgent.shouldShowNotification(notification, accountNotificationPreferences: accountNotificationPreferences)
		else
		{
			return
		}

		let notificationTool = AppDelegate.shared.notificationAgent.notificationTool

		notificationTool.postNotification(mastodonEvent: notification,
		                                  receiverName: account.uri!,
		                                  userAccount: account.uuid,
		                                  detailMode: account.preferences(context: context).notificationDetailMode)
	}

	private func currentUserIsAuthor(of status: Status) -> Bool
	{
		guard status.reblog == nil, let currentAccount = authorizedAccountProvider?.currentAccount else { return false }
		return currentAccount.isSameUser(as: status.account)
	}

	// MARK: - Filtering

	override func applicableFilters() -> [UserFilter]
	{
		return (filterService?.filters ?? []).filter { $0.context.contains(.notifications) }
	}

	override func checkEntry(_ notification: MastodonNotification, matchesFilter filter: UserFilter) -> Bool
	{
		return filter.checkMatch(notification: notification)
	}

	func filterServiceDidUpdateFilters(_ service: FilterService)
	{
		validFiltersDidChange()
	}

	// MARK: - Keyboard Navigation

	override func showPreview(for notification: MastodonKit.Notification, atRow row: Int)
	{
		guard let cellView = tableView.rowView(atRow: row, makeIfNecessary: false)?.view(atColumn: 0),
		      let mediaPresenterCell = cellView as? MediaPresenting
		else
		{
			return
		}

		mediaPresenterCell.makePresentableMediaVisible()
	}

	// MARK: - Reuse Identifiers

	fileprivate enum CellViewIdentifier
	{
		static let status = NSUserInterfaceItemIdentifier("status")
		static let interaction = NSUserInterfaceItemIdentifier("interaction")
		static let follow = NSUserInterfaceItemIdentifier("follow")
	}
}

extension NotificationListViewController: NSMenuItemValidation
{
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
	{
		return cellMenuItemHandler.validateMenuItem(menuItem)
	}

	// not possible until validateMenuItem allows for different view types
//	@IBAction func copyTootLink(_ sender: Any?)
//	{
//		cellMenuItemHandler.copyTootLink(sender)
//	}
//
//	@IBAction func copyTootText(_ sender: Any?)
//	{
//		cellMenuItemHandler.copyTootText(sender)
//	}

	@IBAction func favoriteSelectedStatus(_ sender: Any?)
	{
		cellMenuItemHandler.favoriteSelectedStatus(sender)
	}

	@IBAction func reblogSelectedStatus(_ sender: Any?)
	{
		cellMenuItemHandler.reblogSelectedStatus(sender)
	}

	@IBAction func replyToSelectedStatus(_ sender: Any?)
	{
		cellMenuItemHandler.replyToSelectedStatus(sender)
	}

	@IBAction func toggleMediaVisibilityOfSelectedStatus(_ sender: Any?)
	{
		cellMenuItemHandler.toggleMediaVisibilityOfSelectedStatus(sender)
	}

	@IBAction func toggleContentVisibilityOfSelectedStatus(_ sender: Any?)
	{
		cellMenuItemHandler.toggleContentVisibilityOfSelectedStatus(sender)
	}

	@IBAction func showDetailsOfSelectedStatus(_ sender: Any?)
	{
		cellMenuItemHandler.showDetailsOfSelectedStatus(sender)
	}

	@IBAction func togglePresentableMediaVisible(_ sender: Any?)
	{
		cellMenuItemHandler.togglePresentableMediaVisible(sender)
	}
}

extension NotificationListViewController: ColumnPresentable
{
	var mainResponder: NSResponder
	{
		return tableView
	}

	var modelRepresentation: ColumnModel?
	{
		return ColumnMode.notifications
	}
}

extension MastodonNotification: ListViewPresentable
{
	var key: String
	{
		return id
	}

	var isOfKnownType: Bool
	{
		// these are known, but not currently supported
		switch type
		{
		case .status, .update, .admin_sign_up, .admin_report:
			return false
		default:
			break
		}

		if case .other = type
		{
			return false
		}

		return true
	}
}
