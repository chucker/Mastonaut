//
//  ListViewController.swift
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
import MastodonKit
import CoreTootin
import PullRefreshableScrollView
import SwiftUI

let ListViewControllerMinimumWidth: CGFloat = 280

fileprivate struct ListCellViewIdentifier
{
	static let expander = NSUserInterfaceItemIdentifier("expander")
	static let row = NSUserInterfaceItemIdentifier("row")
	static let filtered = NSUserInterfaceItemIdentifier("filtered")
	
}

class ListViewPullToRefreshAccessoryView : NSView, AccessoryViewForPullRefreshable {
	func viewDidEnterElasticity(_ sender: Any?) {
		print("elasticity entered")
	}
	
	func viewDidEnterValidationArea(_ sender: Any?) {
		print("validation entered")
	}
	
	func viewDidStick(_ sender: Any?) {
		print("sticked")
	}
	
	func viewDidRecede(_ sender: Any?) {
		print("receded")
	}
	
	func viewDidReachElasticityPercentage(_ sender: Any?, percentage: Double) {
		subviews.removeAll()
		let pullToRefreshView = PullToRefreshInnerView(percentage: percentage)
		AppKitSwiftUIIntegration.hostSwiftUIView(pullToRefreshView, inView: self)

		print("percentage : \(percentage)")
	}
}

class ListViewController<Entry: ListViewPresentable & Codable>: NSViewController,
																MastonautTableViewDelegate,
																PullRefreshableScrollViewDelegate,
																NSTableViewDataSource,
																RemoteEventsReceiver,
																ClientObserver
{
	// MARK: - Pull to Refresh
	func prScrollView(_ sender: PullRefreshableScrollView, triggeredOnEdge: PullRefreshableScrollView.ViewEdge) -> Bool {
		reload()
		
		// the [readme](https://github.com/deicoon/PullRefreshableScrollView/blob/639e37e811c50cf39264f125e6df12eeec35f0e4/README.md)
		// seems to say we're supposed to return `true`, but returning `false` seems to be easiest
		// to un-stick the accessory view
		return false
	}
	
	@IBOutlet var topPullToRefreshAccessoryView : ListViewPullToRefreshAccessoryView!
	
	var topAccessoryView: (NSView & AccessoryViewForPullRefreshable)? {
		get {
			return topPullToRefreshAccessoryView
		}
	}
	
	@IBOutlet internal private(set) unowned var scrollView: PullRefreshableScrollView!
	@IBOutlet internal private(set) unowned var tableView: NSTableView!
	@IBOutlet internal private(set) unowned var topConstraint: NSLayoutConstraint!

	internal lazy var loadingIndicator: NSProgressIndicator =
		{
			let indicator = NSProgressIndicator()
			indicator.translatesAutoresizingMaskIntoConstraints = false
			indicator.style = .spinning
			indicator.controlSize = .regular
			indicator.isIndeterminate = true
			return indicator
		}()

	private var notificationObservers = [NSObjectProtocol]()
	private var remoteEventReceiver: ReceiverRef? = nil
	private var eventsHandlerReconnectDelay: TimeInterval = 1
	private var expandersPendingLoadCompletion: Set<Array<EntryReference>.Index> = []
	private var isSystemSleeping = false

	internal var lastPaginationResult: Pagination?

	internal var automaticallyInsertsExpander: Bool
	{
		return true
	}

	private var pendingFetchTasks: Set<FutureTask> = []

	internal private(set) var entryMap: [String: Entry] = [:]
	internal private(set) var entryList: [EntryReference] = []
	{
		didSet
		{
			updateBackgroundView()
		}
	}

	internal private(set) var filteredEntryKeys: Set<String> = []
	internal private(set) var revealedFilteredEntryKeys: Set<String> = []

	#if DEBUG
	private var statusIndicator: NSImageView? = nil
	#endif

	var client: ClientType?
	{
		didSet
		{
			if oldValue?.accessToken != client?.accessToken { clientDidChange(client, oldClient: oldValue) }
		}
	}

	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		needsLoadingIndicator = true

		tableView.target = self
		tableView.doubleAction = #selector(ListViewController.didDoubleClickTableView(_:))

		scrollView.drawsBackground = false
		scrollView.contentView.drawsBackground = false

		if let backgroundView = view as? BackgroundView
		{
			backgroundView.backgroundColor = NSColor(named: "TimelinesBackground")!
		}

		updateBackgroundView()

		registerCells()

		let workspaceNC = NSWorkspace.shared.notificationCenter

		notificationObservers.append(workspaceNC.addObserver(forName: NSWorkspace.willSleepNotification,
															 object: nil,
															 queue: .main)
			{
				[weak self] _ in

				#if DEBUG
				NSLog("Disconnecting events socket…")
				#endif

				self?.isSystemSleeping = true

				if let receiver = self?.remoteEventReceiver
				{
					RemoteEventsCoordinator.shared.remove(receiver: receiver)
				}
			})

		notificationObservers.append(workspaceNC.addObserver(forName: NSWorkspace.didWakeNotification,
															 object: nil,
															 queue: .main)
			{
				[weak self] _ in

				#if DEBUG
				NSLog("Rescheduling events socket reconnection…")
				#endif

				self?.isSystemSleeping = false

				// Once the fetch completes, the socket will be reconnected.
				self?.fetchEntries(for: .detachedAbove)
			})

		notificationObservers.append(NSAccessibility.observeReduceMotionPreference() {
			[weak self] in
			self?.refreshVisibleCellViews()
		})

		view.widthAnchor.constraint(greaterThanOrEqualToConstant: ListViewControllerMinimumWidth).isActive = true
	}

	deinit
	{
		#if DEBUG
		statusIndicator?.removeFromSuperview()
		#endif
		notificationObservers.forEach({ NSWorkspace.shared.notificationCenter.removeObserver($0) })
	}

	func registerCells()
	{
		tableView.register(NSNib(nibNamed: "ExpanderCellView", bundle: .main), forIdentifier: ListCellViewIdentifier.expander)
		tableView.register(NSNib(nibNamed: "BackgroundTableRowView", bundle: .main), forIdentifier: ListCellViewIdentifier.row)
		tableView.register(NSNib(nibNamed: "FilteredEntryCellView", bundle: .main), forIdentifier: ListCellViewIdentifier.filtered)
	}

	override func removeFromParent()
	{
		super.removeFromParent()

		if let receiver = remoteEventReceiver
		{
			RemoteEventsCoordinator.shared.remove(receiver: receiver)
			remoteEventReceiver = nil
		}
	}

	override func awakeFromNib()
	{
		super.awakeFromNib()

		if client != nil
		{
			fetchEntries(for: .above)
		}
		else
		{
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
				{
					// Wait for initial loading to maybe install loading indicator.
					self.installLoadingIndicatorIfNeeded()
				}
		}
	}

	private func updateBackgroundView()
	{
		(view as? BackgroundView)?.drawsBackground = entryList.isEmpty
	}

	internal func clientDidChange(_ client: ClientType?, oldClient: ClientType?)
	{
		oldClient?.removeObserver(self)
		client?.addObserver(self)
		reload()
	}

	func reload() {
		needsLoadingIndicator = true
		
		lastPaginationResult = nil
		revealedFilteredEntryKeys.removeAll()
		reloadList()
	}

	internal func reloadList()
	{
		assert(Thread.isMainThread)
		
		let entryCount = entryList.count
		var removedIndexSet = IndexSet(0..<entryCount)

		pendingFetchTasks.forEach({ $0.task?.cancel() })
		pendingFetchTasks.removeAll()

		entryList.removeAll(where: { $0.isSpecial == false })
		cleanupSpecialRows(&entryList)

		entryMap.removeAll()

		entryList.enumerated().forEach({ removedIndexSet.remove($0.0) })

		guard tableView != nil else { return }

		if client != nil
		{
			tableView.removeRows(at: removedIndexSet, withAnimation: .effectFade)
			if entryList.isEmpty { insertSpecialRows() }
			fetchEntries(for: .above)
		}
		else
		{
			if entryList.isEmpty { insertSpecialRows() }
			tableView.reloadData()
		}
	}

	internal func insertSpecialRows()
	{
	}

	func containerWindowOcclusionStateDidChange(_ occlusionState: NSWindow.OcclusionState)
	{
	}

	func menuItems(for entryReference: EntryReference) -> [NSMenuItem]
	{
		return []
	}

	internal func cleanupSpecialRows(_ entryList: inout [EntryReference])
	{
	}

	internal func insert(entryReferences entryReferenceMap: [Array<EntryReference>.Index: EntryReference])
	{
		for index in entryReferenceMap.keys.sorted()
		{
			entryReferenceMap[index].map { entryList.insert($0, at: index) }
		}

		tableView.insertRows(at: IndexSet(entryReferenceMap.keys), withAnimation: .effectFade)
	}

	internal func refreshVisibleCellViews()
	{
		tableView.enumerateAvailableRowViews
			{
				(_, row) in

				if let cellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView
				{
					prepareToDisplay(cellView: cellView, at: row)
				}
			}
	}

	internal func rangeForEntryFetch(for insertion: InsertionPoint) -> RequestRange
	{
		switch insertion
		{
		case .detachedAbove:
			return .default

		case .above:
			if let firstEntryId = entryList.first(where: { !$0.isExpander })?.entryKey
			{
				return .min(id: firstEntryId, limit: 20)
			}

		case .below:
			if let lastEntryId = entryList.reversed().first(where: { !$0.isExpander })?.entryKey
			{
				return .max(id: lastEntryId, limit: 20)
			}

		case .atIndex(let index):
			if index >= entryList.count {
				// Fixme: This is sort of a fallback for a bad index. It can cause duplicate entries in the list tho.
				return (entryList.last?.entryKey).map { .max(id: $0, limit: 20) } ?? .default
			}

			if let lastEntryIdBeforeIndex = entryList[..<index].reversed().first(where: { !$0.isExpander })?.entryKey
			{
				return .max(id: lastEntryIdBeforeIndex, limit: 20)
			}
		}

		return .default
	}

	internal var needsLoadingIndicator: Bool = false

	internal func fetchEntries(for insertion: InsertionPoint)
	{
		installLoadingIndicatorIfNeeded()
	}

	internal func installLoadingIndicatorIfNeeded()
	{
		if needsLoadingIndicator, loadingIndicator.superview == nil
		{
			installLoadingIndicator()
		}
	}

	internal func installLoadingIndicator()
	{
		let indicator = loadingIndicator
		view.addSubview(indicator)
		indicator.startAnimation(nil)

		NSLayoutConstraint.activate([
			view.centerXAnchor.constraint(equalTo: indicator.centerXAnchor),
			view.centerYAnchor.constraint(equalTo: indicator.centerYAnchor)
		])
	}

	internal func entry(for id: String) -> Entry?
	{
		return entryMap[id]
	}

	internal func run(request: Request<[Entry]>, for insertion: InsertionPoint)
	{
		let futurePromise = Promise<FutureTask>()

		guard let future = client?.run(request, resumeImmediately: false, completion:
			{
				[weak self] (result) in

				DispatchQueue.main.async()
					{
						guard let self = self else { return }

						if let task = futurePromise.value
						{
							guard self.pendingFetchTasks.contains(task) else
							{
								return
							}

							self.pendingFetchTasks.remove(task)
						}

						if let receiver = self.remoteEventReceiver
						{
							RemoteEventsCoordinator.shared.addExisting(receiver: receiver)
						}

						switch result
						{
						case .success(let entries, let pagination):
							self.prepareNewEntries(entries, for: insertion, pagination: pagination)

						case .failure(let error):
							self.failedLoadingEntries(for: request, error: error, insertion: insertion)
						}
					}
			})
		else
		{
			return
		}

		futurePromise.value = future

		// If you hit this you have thread safety issues because pendingFetchTasks
		// is not synchronized and is accessed from the main thread in other places.
		assert(Thread.isMainThread)
		pendingFetchTasks.insert(future)

		future.resolutionHandler = { task in task.resume() }
	}

	internal func failedLoadingEntries(for request: Request<[Entry]>, error: Error?, insertion: InsertionPoint)
	{
		NSLog("Failed fetching timeline: \(error?.localizedDescription ?? "nil error")")

		if case .atIndex(let index) = insertion
		{
			expandersPendingLoadCompletion.remove(index)
			if let expanderCell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? ExpanderCellView
			{
				expanderCell.isLoading = false
			}

			return
		}

		// Fixme: This should be handled better. For now we simply retry after a delay:
		DispatchQueue.main.asyncAfter(deadline: .now() + 10)
		{
			[weak self] in self?.run(request: request, for: insertion)
		}
	}

	internal func prepareNewEntries(_ entries: [Entry], for insertion: InsertionPoint, pagination: Pagination?)
	{
		needsLoadingIndicator = false
		
		let newEntries = entries.filter({ entryMap[$0.key] == nil })
		handleNewEntries(newEntries, for: insertion, pagination: pagination)
	}

	internal func handle(updatedEntry entry: Entry)
	{
		let entryKey = entry.key

		if entryMap[entryKey] != nil
		{
			entryMap[entryKey] = entry

			guard let entryIndex = entryList.firstIndex(where: { $0.entryKey == entryKey }) else
			{
				return
			}

			if let cell = tableView.view(atColumn: 0, row: entryIndex, makeIfNecessary: false) as? NSTableCellView
			{
				populate(cell: cell, for: entry)
				prepareToDisplay(cellView: cell, at: entryIndex)
			}
		}
	}

	internal func handle(deletedEntry entryKey: String)
	{
		handle(deletedEntry: .entry(key: entryKey))
	}

	internal func handle(deletedEntry entryReference: EntryReference)
	{
		guard let entryIndex = entryList.firstIndex(where: { $0 == entryReference }) else
		{
			return
		}

		entryList.remove(at: entryIndex)
		entryReference.entryKey.map { _ = entryMap.removeValue(forKey: $0) }
		tableView.removeRowsAnimatingIfVisible(at: IndexSet(integer: entryIndex))
	}

	private func handleNewEntries(_ entries: [Entry], for insertion: InsertionPoint, pagination: Pagination?)
	{
		assert(Thread.isMainThread)

		loadingIndicator.removeFromSuperview()
		lastPaginationResult = pagination

		let insertionIndex: Array<EntryReference>.Index
		var newExpanderIndex: Array<EntryReference>.Index? = nil
		var shouldTruncateList = false

		let nextPageEntryId: String? = pagination?.next?.id
		let previousPageEntryId: String? = pagination?.previous?.id

		switch insertion
		{
		case .detachedAbove:
			insertionIndex = entryList.firstIndex(where: { !$0.isSpecial }) ?? entryList.endIndex
			newExpanderIndex = nextPageEntryId.map({ entryMap.keys.contains($0) }) == false ? entries.count : nil
			shouldTruncateList = true

		case .above:
			if previousPageEntryId.map({ entryMap.keys.contains($0) }) == false
			{
				newExpanderIndex = entryList.firstIndex(where: { !$0.isSpecial }) ?? entryList.endIndex
				insertionIndex = (newExpanderIndex ?? 0) + 1
			}
			else
			{
				insertionIndex = entryList.firstIndex(where: { !$0.isSpecial }) ?? entryList.lastIndex

				if entryMap.isEmpty
				{
					newExpanderIndex = insertionIndex + entries.count
				}
			}

			shouldTruncateList = true

		case .below:
			insertionIndex = entryList.reversed().firstIndex(where: { $0.isExpander }) ?? entryList.endIndex
			newExpanderIndex = insertionIndex + entries.count + 1

		case .atIndex(let index):
			guard index <= entryList.count else { return }

			insertionIndex = index

			if entries.isEmpty, entryMap.isEmpty
			{
				newExpanderIndex = index
			}
			else
			{
				newExpanderIndex = nextPageEntryId.map({ entryMap.keys.contains($0) }) == false ? index + entries.count
																								: nil
			}
		}

		for newEntry in entries
		{
			entryMap[newEntry.key] = newEntry
		}

		expandersPendingLoadCompletion.remove(insertionIndex)

		var rowToSelect: Int? = nil

		tableView.beginUpdates()

		if insertionIndex < entryList.count, entryList[insertionIndex].isExpander
		{
			if tableView.selectedRowIndexes.contains(insertionIndex) {
				rowToSelect = insertionIndex
			}

			entryList.remove(at: insertionIndex)
			tableView.removeRowsAnimatingIfVisible(at: IndexSet(integer: insertionIndex))
		}

		func insertExpanderRow(at index: Array<EntryReference>.Index)
		{
			guard automaticallyInsertsExpander else { return }

			entryList.insert(.expander, at: index)
			tableView.insertRowsAnimatingIfVisible(at: IndexSet(integer: index))
		}

		if let index = newExpanderIndex, index < insertionIndex
		{
			insertExpanderRow(at: index)
		}

		entryList.insert(contentsOf: entries.map({ EntryReference.entry(key: $0.key ) }), at: insertionIndex)
		tableView.insertRowsAnimatingIfVisible(at: IndexSet(insertionIndex..<insertionIndex + entries.count))

		if let index = newExpanderIndex, index >= insertionIndex
		{
			insertExpanderRow(at: index)
		}

		if shouldTruncateList
		{
			truncateEntriesIfNeeded()
		}

		tableView.endUpdates()

		if let row = rowToSelect {
			tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
		}
	}

	private func truncateEntriesIfNeeded(maxCount: Int = 150)
	{
		guard entryList.count > maxCount, tableView.visibleRect.maxY / tableView.bounds.height < 0.5 else { return }

		let entriesToRemove: [(offset: Int, element: ListViewController<Entry>.EntryReference)] =
			entryList.enumerated().suffix(entryList.count - maxCount).filter({ $0.element.entryKey != nil })

		guard entriesToRemove.isEmpty == false else { return }

		let rowsToRemove = entriesToRemove.map({ $0.offset })

		for (row, entry) in entriesToRemove.sorted(by: { $0.offset < $1.offset }).reversed()
		{
			assert(entry.isExpander == false)
			entryList.remove(at: row)
			entryMap.removeValue(forKey: entry.entryKey!)
		}

		tableView.removeRowsAnimatingIfVisible(at: IndexSet(rowsToRemove))
	}

	// MARK: Websocket

	internal func setClientEventStream(_ stream: RemoteEventsListener.Stream)
	{
		if let receiver = self.remoteEventReceiver
		{
			RemoteEventsCoordinator.shared.remove(receiver: receiver)
			self.remoteEventReceiver = nil
		}

		guard let streamIdentifier = client?.makeStreamIdentifier(for: stream) else { return }

		self.remoteEventReceiver = RemoteEventsCoordinator.shared.add(receiver: self, for: streamIdentifier)
	}

	// MARK: - Filtering

	func applicableFilters() -> [UserFilter] {
		return []
	}

	func entryMatchesAnyFilter(_ entry: Entry) -> Bool {
		guard revealedFilteredEntryKeys.contains(entry.key) == false else {
			return false
		}

		if filteredEntryKeys.contains(entry.key) {
			return true
		}

		let isMatch = applicableFilters().first(where: { self.checkEntry(entry, matchesFilter: $0) }) != nil

		if isMatch {
			filteredEntryKeys.insert(entry.key)
		}

		return isMatch
	}

	func checkEntry(_ entry: Entry, matchesFilter: UserFilter) -> Bool {
		return false
	}

	func validFiltersDidChange() {
		guard entryMap.isEmpty == false else { return }

		assert(Thread.isMainThread)

		let previouslyFilteredEntryKeys = filteredEntryKeys
		filteredEntryKeys.removeAll()

		var rowsNeedingReload = IndexSet()

		tableView.enumerateAvailableRowViews { (_, row) in
			if case .entry(let entryKey) = entryList[row], let entry = entryMap[entryKey] {
				if entryMatchesAnyFilter(entry) || previouslyFilteredEntryKeys.contains(entry.key) {
					rowsNeedingReload.insert(row)
				}
			}
		}

		tableView.beginUpdates()
		tableView.reloadData(forRowIndexes: IndexSet(rowsNeedingReload), columnIndexes: IndexSet(integer: 0))
		tableView.endUpdates()
	}

	// MARK: Table View Data Source

	func numberOfRows(in tableView: NSTableView) -> Int
	{
		return entryList.count
	}

	// MARK: Table View Delegate

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView?
	{
		let rowView = tableView.makeView(withIdentifier: ListCellViewIdentifier.row,
										 owner: nil) as? BackgroundTableRowView
		rowView?.rowIndex = row
		return rowView
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
	{
		let item = entryList[row % entryList.count]
		let view: NSView?

		if case .entry(let key) = item, let entry = entryMap[key]
		{
			let cellViewIdentifier: NSUserInterfaceItemIdentifier

			if entryMatchesAnyFilter(entry) {
				cellViewIdentifier = ListCellViewIdentifier.filtered
			} else {
				cellViewIdentifier = self.cellViewIdentifier(for: entry)
			}

			view = tableView.makeView(withIdentifier: cellViewIdentifier, owner: nil)

			if let cellView = view as? NSTableCellView
			{
				populate(cell: cellView, for: entry)
			}
		}
		else if case .expander = item
		{
			view = tableView.makeView(withIdentifier: ListCellViewIdentifier.expander, owner: nil)

			if let cellView = view as? ExpanderCellView
			{
				cellView.isLoading = expandersPendingLoadCompletion.contains(row)
			}
		}
		else if case .special(let key) = item
		{
			view = tableView.makeView(withIdentifier: cellIdentifier(for: key), owner: nil)

			if let cellView = view as? NSTableCellView
			{
				populate(specialCell: cellView, for: key)
			}
		}
		else
		{
			view = nil
		}

		if let cellView = view as? NSTableCellView
		{
			prepareToDisplay(cellView: cellView, at: row)
		}

		return view
	}

	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool
	{
		guard row >= 0 else { return false }
		
		if entryList[row].isSpecial {
			return shouldSelectSpecialRow(at: row)
		} else {
			return true
		}
	}
	
	func shouldSelectSpecialRow(at index: Int) -> Bool {
		return true
	}

	func tableView(_ tableView: NSTableView,
				   shouldTypeSelectFor event: NSEvent,
				   withCurrentSearch searchString: String?) -> Bool {
		false
	}

	func tableViewSelectionDidChange(_ notification: Foundation.Notification)
	{
		let selectedRow = tableView.selectedRow

		guard selectedRow >= 0 else { return }

		switch entryList[selectedRow]
		{
		case .expander where tableView.selectedRow != -1:
			tableView.deselectRow(selectedRow)
			fetchEntries(forExpanderAt: selectedRow, cellView: nil)

			// Disabled revealing filtered toots for now, as we need to find a good UX to re-hide them
//		case .entry(let key) where filteredEntryKeys.contains(key) && revealedFilteredEntryKeys.contains(key) == false:
//			revealedFilteredEntryKeys.insert(key)
//			tableView.beginUpdates()
//			// Note: Calling `reloadData(forRowIndexes:columnIndexes:)` causes references to the old cell view to
//			// linger causing layout engine issues. That's why remove/insert is called instead.
//			tableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .effectFade)
//			tableView.insertRows(at: IndexSet(integer: selectedRow), withAnimation: .effectGap)
//			tableView.endUpdates()

		default:
			break
		}
	}

	@objc func didDoubleClickTableView(_ sender: Any?)
	{
		let row = tableView.clickedRow

		if row >= 0, row < entryList.count, let key = entryList[row].entryKey, let entry = entryMap[key]
		{
			didDoubleClickRow(for: entry)
		}
	}

	internal func entry(for reference: EntryReference) -> Entry?
	{
		return reference.entryKey.flatMap({ entryMap[$0] })
	}

	internal func prepareToDisplay(cellView: NSTableCellView, at row: Int)
	{
		let entryReference = entryList[row]

		if entryReference.isExpander, !entryMap.isEmpty, row == entryList.count - 1
		{
			DispatchQueue.main.async
				{
					[weak self] in self?.fetchEntries(forExpanderAt: row, cellView: cellView)
				}
		}
		else if let richTextTableCellView = cellView as? RichTextCapable, let window = view.window
		{
			let shouldAnimate = !NSAccessibility.shouldReduceMotion && window.occlusionState.contains(.visible)
			richTextTableCellView.set(shouldDisplayAnimatedContents: shouldAnimate)
		}
		
		if var selectableCellView = cellView as? Selectable {
			selectableCellView.isSelected = tableView.selectedRowIndexes.contains(row)
		}

		if var lazyMenuCell = cellView as? LazyMenuProviding
		{
			lazyMenuCell.menuItemsProvider = { [weak self] in self?.menuItems(for: entryReference) }
		}
	}

	private func fetchEntries(forExpanderAt row: Int, cellView: NSTableCellView?)
	{
		if !expandersPendingLoadCompletion.contains(row),
			let cellView = cellView ?? tableView.view(atColumn: 0, row: row, makeIfNecessary: false),
			let expanderView = cellView as? ExpanderCellView
		{
			expandersPendingLoadCompletion.insert(row)
			fetchEntries(for: .atIndex(row))
			expanderView.isLoading = true
		}
	}

	// MARK: Abstract Methods

	internal func receivedClientEvent(_ event: ClientEvent)
	{
		fatalError("receivedClientEvent(_:) must be overwritten by subclasses!")
	}

	internal func cellViewIdentifier(for entry: Entry) -> NSUserInterfaceItemIdentifier
	{
		fatalError("cellViewIdentifier(for:) must be overwritten by subclasses!")
	}

	internal func didDoubleClickRow(for entry: Entry)
	{
		fatalError("didDoubleClickRow(for:) must be overwritten by subclasses!")
	}

	internal func showPreview(for entry: Entry, atRow row: Int)
	{
		fatalError("showPreview(for:atRow:) must be overwritten by subclasses!")
	}

	internal func populate(cell: NSTableCellView, for entry: Entry)
	{
		fatalError("populate(cell:for:) must be overwritten by subclasses!")
	}

	internal func populate(specialCell: NSTableCellView, for specialCellKey: String)
	{
		fatalError("populate(specialCell:for:) must be overwritten by subclasses!")
	}

	internal func cellIdentifier(for specialCellKey: String) -> NSUserInterfaceItemIdentifier
	{
		fatalError("cellIdentifier(for:) must be overriden by subclasses that make use of .special rows!")
	}

	// MARK: Remote Evenets Receiver

	func remoteEventsCoordinator(streamIdentifierDidConnect stream: StreamIdentifier)
	{
		#if DEBUG
		DispatchQueue.main.async { self.showStatusIndicator(state: .green) }
		#endif

		eventsHandlerReconnectDelay = 0.5
	}

	func remoteEventsCoordinator(streamIdentifierDidDisconnect stream: StreamIdentifier)
	{
		#if DEBUG
		DispatchQueue.main.async { self.showStatusIndicator(state: .amber) }
		#endif

		guard !isSystemSleeping else { return }

		// We can simply dispatch a fetch since we ensure we don't insert duplicate statuses in the timelines.
		eventsHandlerReconnectDelay = min(10, eventsHandlerReconnectDelay * 2)
		DispatchQueue.main.asyncAfter(deadline: .now() + eventsHandlerReconnectDelay)
			{
				self.fetchEntries(for: .detachedAbove)
			}
	}

	func remoteEventsCoordinator(streamIdentifier: StreamIdentifier, didHandleEvent event: ClientEvent)
	{
		receivedClientEvent(event)
	}

	func remoteEventsCoordinator(streamIdentifier: StreamIdentifier, parserProducedError error: Error)
	{
		#if DEBUG
		NSLog("Events Handler produced error: \(error)")
		DispatchQueue.main.async { self.showStatusIndicator(state: .red) }
		#endif
	}

	// MARK: - Keyboard Interaction

	var currentFocusRegion: NSRect? {
		guard let selectedRow = tableView.selectedRowIndexes.first,
			  let rowView = tableView.rowView(atRow: selectedRow, makeIfNecessary: false)
		else {
			return nil
		}

		return tableView.enclosingScrollView?.convert(rowView.frame, from: tableView)
	}

	func controlTextDidEndEditing(_ obj: Foundation.Notification) {
		didDoubleClickTableView(nil)
	}

	func activateKeyboardNavigation(preferredFocusRegion: NSRect?) {
		guard tableView.selectedRowIndexes.isEmpty, entryList.isEmpty == false else {
			return
		}

		if selectBestRowIfPossible(for: preferredFocusRegion) == false {
			tableView.selectFirstVisibleRow()
		}
	}

	func deactivateKeyboardNavigation() {
		tableView.deselectAll(nil)
	}

	private func selectBestRowIfPossible(for preferredFocusRegion: NSRect?) -> Bool {
		guard let region = preferredFocusRegion.flatMap({ tableView.enclosingScrollView?.convert($0, to: tableView) }) else { return false }

		var bestRow: (distanceY: CGFloat, rowIndex: Int) = (.greatestFiniteMagnitude, -1)

		tableView.enumerateAvailableRowViews { (rowView, rowIndex) in
			guard region.intersects(rowView.frame) else { return }

			let distance = abs(rowView.frame.midY - region.midY)

			guard distance < bestRow.distanceY else { return }

			bestRow = (distance, rowIndex)
		}

		guard bestRow.rowIndex >= 0 else { return false }

		tableView.selectRowIndexes(IndexSet(integer: bestRow.rowIndex), byExtendingSelection: false)
		tableView.scrollRowToVisible(bestRow.rowIndex)

		return true
	}

	// MARK: - MastonautTableViewDelegate

	func tableViewDidResignFirstResponder(_ tableView: MastonautTableView) {
		deactivateKeyboardNavigation()
	}

	func tableView(_ tableView: MastonautTableView, shouldTogglePreviewForRow rowIndex: Int) {
		if let entryKey = entryList[bounded: rowIndex], let entry = entry(for: entryKey) {
			showPreview(for: entry, atRow: rowIndex)
		}
	}

	// MARK: - ClientObserver

	func client(_ client: ClientType, didUpdate accessToken: String) {
		if entryMap.isEmpty {
			reloadList()
		}
	}

	// MARK: - Helper Types

	internal enum EntryReference: Equatable
	{
		case entry(key: Dictionary<String, Entry>.Key)
		case special(key: String)
		case expander

		var entryKey: String?
		{
			if case .entry(let entryKey) = self { return entryKey }
			return nil
		}

		var isExpander: Bool
		{
			if case .expander = self { return true }
			return false
		}

		var isSpecial: Bool
		{
			if case .special = self { return true }
			return false
		}

		var specialKey: String?
		{
			if case .special(let key) = self { return key }
			return nil
		}
	}

	internal enum InsertionPoint
	{
		/// Entries are the latest available at the moment, and should be placed on the top of the entry list view,
		/// with an expander item in between the last new entries and the first old entries.
		case detachedAbove

		/// Entries are the chronological successors of the current-latest stauses. Should be placed directly above
		/// the current entries without an expander item.
		case above

		/// Entries are the chronological predecessors of the current-latest stauses. Should be placed directly
		/// below the current entries without an expander item.
		case below

		/// Entries are intermediaries of the the current status collection, and fecthing them will fill (at least part)
		/// of a gap in the status list. Should be placed at the parameter index, potentially replacing an expander
		/// cell at that index, and also possibliy inserting a new expander cell.
		case atIndex(Array<EntryReference>.Index)
	}
}

protocol ListViewPresentable
{
	var key: String { get }
}

#if DEBUG
extension ListViewController
{
	internal func showStatusIndicator(state: IndicatorStyle)
	{
		let indicator: NSImageView = self.statusIndicator ??
			{
				let indicator = NSImageView(frame: .zero)
				indicator.translatesAutoresizingMaskIntoConstraints = false
				indicator.setAccessibilityElement(false)
				view.addSubview(indicator)

				NSLayoutConstraint.activate([
					indicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
					view.rightAnchor.constraint(equalTo: indicator.rightAnchor, constant: 10)
				])

				return indicator
			}()

		indicator.image = NSImage(named: state.rawValue)
	}

	enum IndicatorStyle: NSImage.Name
	{
		case green
		case amber
		case red
		case off

		var rawValue: NSImage.Name
		{
			switch self
			{
			case .green:	return NSImage.statusAvailableName
			case .amber:	return NSImage.statusPartiallyAvailableName
			case .red:		return NSImage.statusUnavailableName
			case .off:		return NSImage.statusNoneName
			}
		}
	}
}
#endif

private extension NSTableView.AnimationOptions
{
	static var none: NSTableView.AnimationOptions = []
}
