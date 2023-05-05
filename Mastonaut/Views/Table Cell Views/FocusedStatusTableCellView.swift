//
//  FocusedStatusTableCellView.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 25.05.19.
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

class FocusedStatusTableCellView: StatusTableCellView
{
	@IBOutlet private unowned var appNameConatiner: NSView!
	@IBOutlet private unowned var appNameLabel: NSButton!

	private func fontService() -> FontService
	{
		return FontService(font: MastonautPreferences.instance.focusedStatusFont)
	}

	@IBOutlet var replyCount: NSTextField!
	@IBOutlet var reblogCount: NSTextField!
	@IBOutlet var favoriteCount: NSTextField!

	private var sourceApplication: Application?

	override func awakeFromNib()
	{
		super.awakeFromNib()

		fontObserver = MastonautPreferences.instance.observe(\.focusedStatusFont, options: .new)
		{
			[weak self] _, _ in
			self?.updateFont()
		}
	}

	private var fontObserver: NSKeyValueObservation?

	deinit
	{
		fontObserver?.invalidate()
	}

	override func updateFont()
	{
		statusLabel.linkTextAttributes = statusLabelLinkAttributes()

		redraw()
	}

	override internal func authorLabelAttributes() -> [NSAttributedString.Key: AnyObject]
	{
		return fontService().authorAttributes()
	}

	override internal func statusLabelAttributes() -> [NSAttributedString.Key: AnyObject]
	{
		return fontService().statusAttributes()
	}

	override internal func statusLabelLinkAttributes() -> [NSAttributedString.Key: AnyObject]
	{
		return fontService().statusLinkAttributes()
	}

	override func set(displayedStatus status: Status,
	                  poll: Poll?,
	                  attachmentPresenter: AttachmentPresenting,
	                  interactionHandler: StatusInteractionHandling,
	                  activeInstance: Instance)
	{
		super.set(displayedStatus: status,
		          poll: poll,
		          attachmentPresenter: attachmentPresenter,
		          interactionHandler: interactionHandler,
		          activeInstance: activeInstance)

		setContentLabelsSelectable(true)

		if let application = status.application
		{
			sourceApplication = application
			appNameLabel.title = application.name
			appNameLabel.isEnabled = application.website != nil
			appNameConatiner.isHidden = false
		}
		else
		{
			appNameLabel.title = ""
			appNameConatiner.isHidden = true
		}

		reblogCount.intValue = Int32(status.reblogsCount)
		favoriteCount.intValue = Int32(status.favouritesCount)
	}

	func set(context: Context)
	{
		replyCount.intValue = Int32(context.descendants.count)
	}

	override func prepareForReuse()
	{
		super.prepareForReuse()

		sourceApplication = nil
	}

	@IBAction func showStatusApp(_ sender: Any?)
	{
		guard let applicationWebsite = sourceApplication?.website, let url = URL(string: applicationWebsite)
		else
		{
			return
		}

		NSWorkspace.shared.open(url)
	}
}
