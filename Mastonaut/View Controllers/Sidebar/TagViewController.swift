//
//  TagViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 13.04.19.
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

class TagViewController: TimelineViewController, SidebarPresentable
{
	let tag: String
	private let titleButtonBindable: SidebarTitleButtonsStateBindable?

	private let tagBookmarkService: TagBookmarkService?
	private let tagFollowService: TagFollowService?

	var sidebarModelValue: SidebarModel
	{
		return SidebarMode.tag(tag)
	}

	var titleMode: SidebarTitleMode
	{
		return titleButtonBindable.map { .buttons($0, .title("#\(tag)")) } ?? .title("#\(tag)")
	}

	init(tag: String, tagBookmarkService: TagBookmarkService?, tagFollowService: TagFollowService?)
	{
		self.tag = tag

		if let tagBookmarkService, let tagFollowService
		{
			self.titleButtonBindable = TagButtonsStateBindable(tag: tag,
			                                                   tagBookmarkService: tagBookmarkService,
			                                                   tagFollowService: tagFollowService)
			self.tagBookmarkService = tagBookmarkService
			self.tagFollowService = tagFollowService
		}
		else
		{
			self.titleButtonBindable = nil
			self.tagBookmarkService = nil
			self.tagFollowService = nil
		}

		super.init(source: .tag(name: tag))
	}

	@available(*, unavailable)
	required init?(coder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}
}

private class TagButtonsStateBindable: SidebarTitleButtonsStateBindable
{
	let tag: String

	unowned let tagBookmarkService: TagBookmarkService
	unowned let tagFollowService: TagFollowService

	init(tag: String, tagBookmarkService: TagBookmarkService, tagFollowService: TagFollowService)
	{
		self.tag = tag
		self.tagBookmarkService = tagBookmarkService
		self.tagFollowService = tagFollowService

		super.init()

		updateBookmarkButton()
		updateFollowButton()
	}

	private func updateBookmarkButton()
	{
		let isBookmarked = tagBookmarkService.isTagBookmarked(tag)
		firstIcon = isBookmarked ? #imageLiteral(resourceName: "bookmark_active") : #imageLiteral(resourceName: "bookmark")
		firstAccessibilityLabel = isBookmarked ? 🔠("Unbookmark Tag") : 🔠("Bookmark Tag")
	}

	private func updateFollowButton()
	{
		Task
		{
			let isFollowed = await tagFollowService.isTagFollowed(tag)

			await MainActor.run
			{
				secondAccessibilityLabel = isFollowed ? 🔠("Unfollow Tag on Timeline") : 🔠("Follow Tag on Timeline")
				secondIcon = NSImage(systemSymbolName: isFollowed ? "rectangle.fill.badge.xmark": "rectangle",
				                     accessibilityDescription: secondAccessibilityLabel)
			}
		}
	}

	override func didClickFirstButton(_ sender: Any?)
	{
		tagBookmarkService.toggleBookmarkedState(for: tag)
		updateBookmarkButton()
	}

	override func didClickSecondButton(_ sender: Any?)
	{
		Task
		{
			await tagFollowService.toggleFollowedState(for: tag)

			updateFollowButton()
		}
	}
}
