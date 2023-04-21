//
//  TimelineViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 26.12.18.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2018 Bruno Philipe.
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
import Logging
import MastodonKit

class TimelineViewController: StatusListViewController
{
	private var logger: Logger

	private var markerTimer: Timer?

	internal var source: Source?
	{
		didSet { if source != oldValue { sourceDidChange(source: source) }}
	}

	init(source: Source?)
	{
		self.source = source

		logger = Logger(subsystemType: Self.self)

		markerBehavior = .active

		super.init()

		if (source != nil) && source == .timeline
		{
			startMarkerTimer(forSource: source!)
		}

		updateAccessibilityAttributes()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}

	internal func sourceDidChange(source: Source?)
	{
		switch source
		{
		case .timeline:
			if let source
			{
				startMarkerTimer(forSource: source)
			}
		default:
			stopMarkerTimerIfRunning()
		}

		updateAccessibilityAttributes()
	}

	// MARK: Timeline Markers

	func startMarkerTimer(forSource source: Source)
	{
		stopMarkerTimerIfRunning()

		markerTimer = Timer.scheduledTimer(timeInterval: 30.0, target: self,
		                                   selector: #selector(updateMarker), userInfo: nil, repeats: true)
	}

	func stopMarkerTimerIfRunning()
	{
		markerTimer?.invalidate()
	}

	func firstVisibleStatus() -> Status?
	{
		let rect = tableView.visibleRect
		let rows = tableView.rows(in: rect)

		for rowIndex in rows.location ..< rows.location + rows.length
		{
			if let view = tableView.view(atColumn: 0, row: rowIndex, makeIfNecessary: false) as? StatusTableCellView,
			   let cellModel = view.cellModel
			{
				return cellModel.status
			}
		}

		logger.warning("Did not find any visible table row containing a status")

		return nil
	}

	public enum MarkerBehavior
	{
		case active
		case passive
		case disabled
	}

	private var markerBehavior: MarkerBehavior
	private var markerSyncProvider: MarkerSyncProvider?

	public func setMarkerBehavior(_ newBehavior: MarkerBehavior) async
	{
		markerBehavior = newBehavior

		switch MastonautPreferences.instance.timelineSyncMode
		{
		case .disabled:
			markerSyncProvider = nil
		case .icloud:
			break
		case .mastodon:
			markerSyncProvider = MastodonAPIMarkerSyncProvider()
		}

		switch newBehavior
		{
		case .active:
			stopMarkerTimerIfRunning()

			await jumpToMarker()

			if let source
			{
				startMarkerTimer(forSource: source)
			}

			logger.debug2("Timeline markers for this column are now `active`, meaning this column will _write_ to the API.")

		case .passive:
			if let source
			{
				startMarkerTimer(forSource: source)
			}

			logger.debug2("Timeline markers for this column are now `passive`, meaning this column will _read_ from the API.")

		case .disabled:
			stopMarkerTimerIfRunning()
		}
	}

	func jumpToMarker() async
	{
		if let client, let homeMarker = await markerSyncProvider?.read(client: client)
		{
			if let firstVisibleStatus = firstVisibleStatus(), homeMarker.lastReadId < firstVisibleStatus.id
			{
				logger.debug2("Not jumping to marker because \(homeMarker.lastReadId) is older than our current position \(firstVisibleStatus.id)")

				return
			}

			var entryIndex = entryList.firstIndex(where: { $0.entryKey == homeMarker.lastReadId })

			if entryIndex == nil
			{
				_ = try? await client.run(Timelines.home(range: .min(id: homeMarker.lastReadId, limit: 20)))

				entryIndex = entryList.firstIndex(where: { $0.entryKey == homeMarker.lastReadId })
			}

			if entryIndex == nil
			{
				logger.warning("Got timeline marker to \(homeMarker.lastReadId), but we don't seem to have that entry, and apparently couldn't fetch it either")
			}
			else
			{
				logger.debug2("Got timeline marker to \(homeMarker.lastReadId); scrolling there")

				tableView.scrollRowToVisible(entryIndex!)
			}
		}
	}

	@objc func updateMarker(timer: Timer)
	{
		switch markerBehavior
		{
		case .active:
			setMarker()
		case .passive:
			Task
			{
				await jumpToMarker()
			}
		case .disabled:
			break
		}
	}

	func setMarker()
	{
		if let firstVisibleStatus = firstVisibleStatus(),
		   let client
		{
			logger.debug2("Updating timeline marker to \(firstVisibleStatus.id) (\(firstVisibleStatus.authorAccount), \(firstVisibleStatus.createdAt))")

			let newMarker = Marker(lastReadStatus: firstVisibleStatus)
			
			markerSyncProvider?.write(client: client,
									  newMarker: newMarker)
		}
	}

	override func clientDidChange(_ client: ClientType?, oldClient: ClientType?)
	{
		super.clientDidChange(client, oldClient: oldClient)

		guard let source = source
		else
		{
			return
		}

		switch source
		{
		case .timeline:
			setClientEventStream(.user)

		case .localTimeline:
			setClientEventStream(.publicLocal)

		case .publicTimeline:
			setClientEventStream(.public)

		case .list(let list):
			setClientEventStream(.list(list))

		case .tag(let name):
			setClientEventStream(.hashtag(name))

		case .userStatuses, .userMediaStatuses, .userStatusesAndReplies, .favorites, .bookmarks:
			#if DEBUG
			DispatchQueue.main.async { self.showStatusIndicator(state: .off) }
			#endif
		}
	}

	override internal func fetchEntries(for insertion: InsertionPoint)
	{
		guard let source = source
		else
		{
			return
		}

		super.fetchEntries(for: insertion)

		let request: Request<[Status]>

		switch source
		{
		case .timeline:
			request = Timelines.home(range: rangeForEntryFetch(for: insertion))

		case .publicTimeline:
			request = Timelines.public(local: false, range: rangeForEntryFetch(for: insertion))

		case .localTimeline:
			request = Timelines.public(local: true, range: rangeForEntryFetch(for: insertion))

		case .favorites:
			let range = lastPaginationResult?.next ?? rangeForEntryFetch(for: insertion)
			request = Favourites.all(range: range)

		case .bookmarks:
			let range = lastPaginationResult?.next ?? rangeForEntryFetch(for: insertion)
			request = Bookmarks.all(range: range)

		case .userStatuses(let account):
			request = Accounts.statuses(id: account, excludeReplies: true, range: rangeForEntryFetch(for: insertion))

		case .userStatusesAndReplies(let account):
			request = Accounts.statuses(id: account, excludeReplies: false, range: rangeForEntryFetch(for: insertion))

		case .userMediaStatuses(let account):
			request = Accounts.statuses(id: account, mediaOnly: true, range: rangeForEntryFetch(for: insertion))

		case .list(let listId):
			request = Timelines.list(listId.id!, range: rangeForEntryFetch(for: insertion))

		case .tag(let tagName):
			request = Timelines.tag(tagName, range: rangeForEntryFetch(for: insertion))
		}

		run(request: request, for: insertion)
	}

	override func receivedClientEvent(_ event: ClientEvent)
	{
		switch event
		{
		case .update(let status):
			DispatchQueue.main.async
			{
				[weak self] in

				guard let self = self else { return }

				if self.entryMap[status.key] != nil
				{
					self.handle(updatedEntry: status)
				}
				else
				{
					self.prepareNewEntries([status], for: .above, pagination: nil)
				}
			}

		case .delete(let statusID):
			DispatchQueue.main.async { [weak self] in self?.handle(deletedEntry: statusID) }

		case .notification:
			break

		case .keywordFiltersChanged:
			break
		}
	}

	override func viewDidLoad()
	{
		super.viewDidLoad()

		updateAccessibilityAttributes()
	}

	private func updateAccessibilityAttributes()
	{
		guard isViewLoaded, let source = source
		else
		{
			tableView?.setAccessibilityLabel(nil)
			return
		}

		switch source
		{
		case .timeline:
			tableView.setAccessibilityLabel("Home Timeline")
		case .localTimeline:
			tableView.setAccessibilityLabel("Local Timeline")
		case .publicTimeline:
			tableView.setAccessibilityLabel("Public Timeline")
		case .favorites:
			tableView.setAccessibilityLabel("Favorites Timeline")
		case .list(let name):
			tableView.setAccessibilityLabel("Timelinen for list \(name)")
		case .tag(let name):
			tableView.setAccessibilityLabel("Timeline for tag \(name)")
		default:
			break
		}
	}

	override func applicableFilters() -> [UserFilter]
	{
		guard let source = source
		else
		{
			return super.applicableFilters()
		}

		let currentContext: Filter.Context

		switch source
		{
		case .localTimeline: currentContext = .public
		case .publicTimeline: currentContext = .public

		case .favorites: currentContext = .home
		case .bookmarks: currentContext = .home

		case .list: currentContext = .home
		case .tag: currentContext = .home
		case .timeline: currentContext = .home
		case .userMediaStatuses: currentContext = .account
		case .userStatuses: currentContext = .account
		case .userStatusesAndReplies: currentContext = .account
		}

		return super.applicableFilters().filter { $0.context.contains(currentContext) }
	}

	enum Source: Equatable
	{
		case timeline
		case localTimeline
		case publicTimeline

		case favorites
		case bookmarks

		case userStatuses(id: String)
		case userStatusesAndReplies(id: String)
		case userMediaStatuses(id: String)

		case list(list: FollowedList)
		case tag(name: String)
	}
}

extension TimelineViewController: ColumnPresentable
{
	var mainResponder: NSResponder
	{
		return tableView
	}

	var modelRepresentation: ColumnModel?
	{
		guard let source = source
		else
		{
			return nil
		}

		switch source
		{
		case .timeline: return ColumnMode.timeline
		case .localTimeline: return ColumnMode.localTimeline
		case .publicTimeline: return ColumnMode.publicTimeline

		case .favorites: return ColumnMode.favorites
		case .bookmarks: return ColumnMode.bookmarks

		case .list(let name): return ColumnMode.list(list: name)
		case .tag(let name): return ColumnMode.tag(name: name)

		case .userStatuses, .userMediaStatuses, .userStatusesAndReplies:
			return nil
		}
	}
}
