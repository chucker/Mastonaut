//
//  FilterService.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 15.11.19.
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

class FilterService: NSObject, RemoteEventsReceiver {
	// MARK: - Static Logic

	private static var accountServiceMap: [UUID: FilterService] = [:]

	static func service(for account: AuthorizedAccount) -> FilterService? {
		if let service = accountServiceMap[account.uuid] {
			return service
		}

		guard let client = Client.create(for: account) else {
			return nil
		}

		let service = FilterService(client: client, account: account)
		accountServiceMap[account.uuid] = service

		return service
	}

	// MARK: - Instance Logic

	private var client: ClientType
	private var account: AuthorizedAccount
	private var needsUpdate: Bool = false
	private var isUpdating: Bool = false

	private var eventsReceiverRef: ReceiverRef?

	private let observers = NSHashTable<NSObject>(options: .weakMemory)

	private(set) var filters: [UserFilter]? {
		didSet {
			if observers.count > 0 {
				informObserversFiltersChanged()
			}
		}
	}

	init(client: ClientType, account: AuthorizedAccount) {
		self.client = client
		self.account = account
		filters = (account.filters as? Set<CachedFilter>)?.compactMap { UserFilter(filter: $0) }

		super.init()

		setNeedsUpdate()

		guard let streamIdentifier = client.makeStreamIdentifier(for: .user) else {
			return
		}

		eventsReceiverRef = RemoteEventsCoordinator.shared.add(receiver: self, for: streamIdentifier)
	}

	func register(observer: FilterServiceObserver) {
		observers.add(observer)
	}

	func remove(observer: FilterServiceObserver) {
		observers.remove(observer)
	}

	func setNeedsUpdate() {
		setNeedsUpdate(hadFailure: false)
	}

	func delete(filter: UserFilter, completion: @escaping (Result<Empty>) -> Void) {
		client.run(FilterRequests.delete(id: filter.id), completion: completion)
	}

	func create(filter: UserFilter, completion: @escaping (Result<Filter>) -> Void) {
		client.run(FilterRequests.create(phrase: filter.phrase, context: filter.context,
		                                 irreversible: filter.irreversible, wholeWord: filter.wholeWord,
		                                 expiresIn: filter.expiresAt), completion: completion)
	}

	func updateFilter(id: String, updatedFilter filter: UserFilter, completion: @escaping (Result<Filter>) -> Void) {
		client.run(FilterRequests.update(id: id, phrase: filter.phrase, context: filter.context,
		                                 irreversible: filter.irreversible, wholeWord: filter.wholeWord,
		                                 expiresIn: filter.expiresAt), completion: completion)
	}

	private func setNeedsUpdate(hadFailure: Bool) {
		needsUpdate = true

		guard !isUpdating else { return }

		if hadFailure {
			DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
				self?.update()
			}
		} else {
			update()
		}
	}

	private func update() {
		guard needsUpdate, !isUpdating else { return }

		isUpdating = true

		client.runAndAggregateAllPages(requestProvider: { FilterRequests.filters(range: $0.next ?? .default) }) {
			[weak self] result in

			guard let self = self else { return }

			switch result {
			case .success(let filters, _):
				DispatchQueue.main.async {
					self.account.setCachedFilters(from: filters)
					self.filters = filters.map { UserFilter(filter: $0) }
					self.needsUpdate = false
					self.isUpdating = false
				}

			case .failure(let error):
				DispatchQueue.main.async {
					#if DEBUG
					NSLog("FilterService: Error fetching \(error)")
					#endif
					self.isUpdating = false
					self.setNeedsUpdate(hadFailure: true)
				}
			}
		}
	}

	private func informObserversFiltersChanged() {
		observers.objectEnumerator().forEach { object in
			(object as? FilterServiceObserver)?.filterServiceDidUpdateFilters(self)
		}
	}

	// MARK: - RemoteEventsReceiver

	func remoteEventsCoordinator(streamIdentifierDidConnect: StreamIdentifier) {}

	func remoteEventsCoordinator(streamIdentifierDidDisconnect: StreamIdentifier) {}

	func remoteEventsCoordinator(streamIdentifier: StreamIdentifier, didHandleEvent event: ClientEvent) {
		if case .keywordFiltersChanged = event {
			setNeedsUpdate(hadFailure: false)
		}
	}

	func remoteEventsCoordinator(streamIdentifier: StreamIdentifier, parserProducedError: Error) {}
}

struct UserFilter {
	let id: String
	let phrase: String
	let context: [Filter.Context]
	let expiresAt: Date?
	let wholeWord: Bool
	let irreversible: Bool

	init(id: String, phrase: String, context: [Filter.Context], expiresAt: Date?, wholeWord: Bool, irreversible: Bool) {
		self.id = id
		self.phrase = phrase
		self.context = context
		self.expiresAt = expiresAt
		self.wholeWord = wholeWord
		self.irreversible = irreversible
	}

	fileprivate init(filter: Filter) {
		id = filter.id
		phrase = filter.phrase
		context = filter.context
		expiresAt = filter.expiresAt
		wholeWord = filter.wholeWord
		irreversible = filter.irreversible
	}

	fileprivate init?(filter: CachedFilter) {
		guard
			let id = filter.id,
			let phrase = filter.phrase,
			let context = filter.context?.split(separator: ";").compactMap({ Filter.Context(rawValue: String($0)) })
		else {
			return nil
		}
		self.id = id
		self.phrase = phrase
		self.context = context
		expiresAt = filter.expiresAt
		wholeWord = filter.wholeWord
		irreversible = filter.irreversible
	}

	func checkMatch(status: Status) -> Bool {
		guard isValid else { return false }

		let spoiler = status.attributedSpoiler.string

		if spoiler.isEmpty == false, checkMatch(string: spoiler) {
			return true
		}

		let content = status.reblog?.attributedContent.string ?? status.attributedContent.string

		if content.isEmpty == false, checkMatch(string: content) {
			return true
		}

		return false
	}

	func checkMatch(notification: MastodonKit.Notification) -> Bool {
		guard isValid else { return false }

		if let status = notification.status {
			if checkMatch(status: status) {
				return true
			}
		} else {
			if checkMatch(string: notification.account.attributedNote.string) {
				return true
			}
		}

		return false
	}

	private func checkMatch(string: String) -> Bool {
		guard string.isEmpty == false else {
			return false
		}

		if wholeWord {
			return string.matches(regex: "(^|[^\\w])\(phrase)([^\\w]|$)", options: [.caseInsensitive])
		} else {
			return string.contains(phrase)
		}
	}

	var isValid: Bool {
		guard let expiry = expiresAt else {
			return true
		}

		return expiry > Date()
	}
}

protocol FilterServiceObserver: NSObject {
	func filterServiceDidUpdateFilters(_ service: FilterService)
}

private extension AuthorizedAccount {
	func setCachedFilters(from fetchedFilters: [Filter]) {
		guard let context = managedObjectContext else {
			assertionFailure("No context set for authorized account!!")
			return
		}

		context.perform {
			for filter in (self.filters as? Set<CachedFilter>) ?? [] {
				context.delete(filter)
			}

			for filter in fetchedFilters {
				let cachedFilter = CachedFilter(context: context)
				cachedFilter.phrase = filter.phrase
				cachedFilter.context = filter.context.map(\.rawValue).joined(separator: ";")
				cachedFilter.expiresAt = filter.expiresAt
				cachedFilter.wholeWord = filter.wholeWord
				cachedFilter.account = self
			}
		}
	}
}
