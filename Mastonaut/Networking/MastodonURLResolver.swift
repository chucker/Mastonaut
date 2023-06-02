//
//  MastodonURLResolver.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 09.04.19.
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
import Logging
import MastodonKit

struct MastodonURLResolver {
	static func resolveAsync(using client: ClientType?, url: URL, knownTags: [Tag]?, source windowController: TimelinesWindowController?) async
	{
		let logger = Logger(label: "MastodonURLResolver")

		if let mode = getSidebarModeFromAnnotations(url: url, knownTags: knownTags), let windowController = windowController
		{
			logger.info("Resolved \(url); will show in sidebar with mode \(mode)")
			await windowController.presentInSidebar(mode)
		}
		else if #available(macOS 10.15, *), let client, let status = try? await fetchStatusFromUrl(using: client, url: url) {
			logger.info("Resolved \(url); fetched as status as \(status)")
			await windowController?.presentInSidebar(SidebarMode.status(uri: url.absoluteString, status: status))
		}
		else {
			logger.info("Resolved \(url); will open in OS default app")
			NSWorkspace.shared.open(url)
		}
	}
	
	@available(macOS, obsoleted: 11.0)
	static func resolve(using client: ClientType?, url: URL, knownTags: [Tag]?, source windowController: TimelinesWindowController?)
	{
		let logger = Logger(label: "MastodonURLResolver")

		if let mode = getSidebarModeFromAnnotations(url: url, knownTags: knownTags), let windowController = windowController
		{
			logger.info("Resolved \(url); will show in sidebar with mode \(mode)")
			windowController.presentInSidebar(mode)
		}
		else {
			logger.info("Resolved \(url); will open in OS default app")
			NSWorkspace.shared.open(url)
		}
	}
	
	private static func getSidebarModeFromAnnotations(url: URL, knownTags: [Tag]?) -> SidebarMode? {
		var modeToPresent: SidebarMode?
		
		if let annotations = (url as? AnnotatedURL)?.annotation?.split(separator: " ") {
			if annotations.contains("mention") {
				if annotations.contains("u-url") {
					modeToPresent = .profile(uri: url.mastodonHandleFromAccountURI)
				}
				else if annotations.contains("hashtag") {
					if let tag = knownTags?.first(where: { $0.url == url }) {
						modeToPresent = .tag(tag.name)
					}
					else if let leadIndex = url.pathComponents.firstIndex(where: { $0 == "tag" || $0 == "tags" }),
					        leadIndex < url.pathComponents.count
					{
						modeToPresent = .tag(url.pathComponents[leadIndex + 1])
					}
				}
			}
		}
		
		return modeToPresent
	}
	
	@available(macOS 10.15, *)
	private static func fetchStatusFromUrl(using client: ClientType, url: URL) async throws -> Status? {
		/*
		 * TODO: make this a `StatusResolver` that also handles
		 * StatusThreadViewController.resolveStatus, which is
		 * different in that here, we're merely _guessing_ that
		 * a URL might point to a status, but that method _expects_
		 * a status
		 */
		
		let uri = url.absoluteString
		
		var status: Status? = try await withThrowingTaskGroup(of: Status?.self) {
			group in
			
			group.addTask {
				let result = try await client.run(Search.search(query: uri, limit: 1, resolve: true))

				return result.value.statuses.first
			}
			
			group.addTask {
				// we use a short timeout here in case the instance is slow to respond
				try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
				
				return nil
			}
			
			let result: Status? = try await group.next() ?? nil
			group.cancelAll()
			
			return result
		}
		
		return status
	}
}
