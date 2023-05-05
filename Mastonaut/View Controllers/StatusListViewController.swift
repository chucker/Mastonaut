//
//  StatusListViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 09.05.19.
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

import CoreTootin
import Foundation
import MastodonKit

class StatusListViewController: ListViewController<Status>, StatusInteractionHandling, PollVotingCapable, FilterServiceObserver
{
	private var observations: [NSKeyValueObservation] = []
	private var filterService: FilterService?

	internal var updatedPolls: [String: Poll] = [:]
	internal var pollRefreshTimers: [String: Timer] = [:]

	private lazy var cellMenuItemHandler: CellMenuItemHandler = .init(tableView: tableView, interactionHandler: self)

	init()
	{
		super.init(nibName: "ListViewController", bundle: .main)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad()
	{
		super.viewDidLoad()

		observations.observePreference(\MastonautPreferences.mediaDisplayMode)
		{
			[unowned self] _, _ in self.refreshVisibleCellViews()
		}

		observations.observePreference(\MastonautPreferences.spoilerDisplayMode)
		{
			[unowned self] _, _ in self.refreshVisibleCellViews()
		}
	}

	override func containerWindowOcclusionStateDidChange(_ occlusionState: NSWindow.OcclusionState)
	{
		refreshVisibleCellViews()
	}

	override func registerCells()
	{
		super.registerCells()

		tableView.register(NSNib(nibNamed: "StatusTableCellView", bundle: .main),
		                   forIdentifier: CellViewIdentifier.status)
	}

	override func clientDidChange(_ client: ClientType?, oldClient: ClientType?)
	{
		super.clientDidChange(client, oldClient: oldClient)

		guard let account = authorizedAccountProvider?.currentAccount else { return }

		filterService = FilterService.service(for: account)
		filterService?.register(observer: self)
	}

	func handle(updatedStatus: Status)
	{
		handle(updatedEntry: updatedStatus)
	}

	func handle<T: UserDescriptionError>(interactionError error: T)
	{
		DispatchQueue.main.async
		{
			[weak self] in self?.view.window?.windowController?.displayError(error,
			                                                                 title: 🔠("interaction.status"))
		}
	}

	func handle(linkURL: URL, knownTags: [Tag]?)
	{
		authorizedAccountProvider?.handle(linkURL: linkURL, knownTags: knownTags)
	}

	func reply(to statusID: String)
	{
		entry(for: statusID).map { authorizedAccountProvider?.composeReply(for: $0, sender: nil) }
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

	func showStatusEdits(status: Status, edits: [StatusEdit])
	{
		let sidebarMode = SidebarMode.edits(status: status,
		                                    edits: edits)
		authorizedAccountProvider?.presentInSidebar(sidebarMode)
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
		guard let status = entry(for: entryReference) else { return [] }
		return menuItems(for: status)
	}

	func menuItems(for status: Status) -> [NSMenuItem]
	{
		guard entryMatchesAnyFilter(status) == false
		else
		{
			return StatusMenuItemsController.shared.menuItems(forFilteredStatus: status, interactionHandler: self)
		}

		return StatusMenuItemsController.shared.menuItems(for: status, interactionHandler: self)
	}

	override func cellViewIdentifier(for status: Status) -> NSUserInterfaceItemIdentifier
	{
		return StatusListViewController.CellViewIdentifier.status
	}

	override func populate(cell: NSTableCellView, for status: Status)
	{
		guard
			let attachmentPresenter = authorizedAccountProvider?.attachmentPresenter,
			let instance = authorizedAccountProvider?.currentInstance,
			let statusCell = cell as? StatusDisplaying
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
	}

	func set(hasActivePollTask: Bool, for statusID: String)
	{
		guard
			let index = entryList.firstIndex(where: { $0.entryKey == statusID }),
			let statusCell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? StatusTableCellView
		else
		{
			return
		}

		statusCell.setHasActivePollTask(hasActivePollTask)
	}

	func handle(updatedPoll poll: Poll, statusID: String)
	{
		guard let index = entryList.firstIndex(where: { $0.entryKey == statusID })
		else
		{
			return
		}

		updatedPolls[poll.id] = poll

		guard
			let statusCell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? StatusTableCellView
		else
		{
			return
		}

		statusCell.set(updatedPoll: poll)
	}

	override func prepareToDisplay(cellView: NSTableCellView, at row: Int)
	{
		super.prepareToDisplay(cellView: cellView, at: row)

		if let statusCellView = cellView as? StatusTableCellView
		{
			statusCellView.updateContentsVisibility()
		}
	}

	override func didDoubleClickRow(for status: Status)
	{
		show(status: status.reblog ?? status)
	}

	private func currentUserIsAuthor(of status: Status) -> Bool
	{
		guard status.reblog == nil, let currentAccount = authorizedAccountProvider?.currentAccount else { return false }
		return currentAccount.isSameUser(as: status.account)
	}

	// MARK: - Filtering

	override func applicableFilters() -> [UserFilter]
	{
		return filterService?.filters ?? []
	}

	override func checkEntry(_ status: Status, matchesFilter filter: UserFilter) -> Bool
	{
		return filter.checkMatch(status: status)
	}

	func filterServiceDidUpdateFilters(_ service: FilterService)
	{
		validFiltersDidChange()
	}

	// MARK: - Reuse Identifiers

	enum CellViewIdentifier
	{
		static let status = NSUserInterfaceItemIdentifier("status")
	}

	// MARK: - Keyboard Navigation

	override func showPreview(for status: Status, atRow row: Int)
	{
		guard let cellView = tableView.rowView(atRow: row, makeIfNecessary: false)?.view(atColumn: 0),
		      let mediaPresenterCell = cellView as? MediaPresenting
		else
		{
			return
		}

		mediaPresenterCell.makePresentableMediaVisible()
	}
}

extension StatusListViewController: NSMenuItemValidation
{
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
	{
		return cellMenuItemHandler.validateMenuItem(menuItem)
	}

	@IBAction func copy(_ sender: Any?)
	{
		cellMenuItemHandler.copy(sender)
	}

	@IBAction func copyTootText(_ sender: Any?)
	{
		cellMenuItemHandler.copyTootText(sender)
	}

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

extension Status: ListViewPresentable
{
	var key: String
	{
		return id
	}
}
