//
//  StatusSearchResultViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 02.07.19.
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

class StatusSearchResultsViewController: SearchResultsViewController<Status>
{
	@IBOutlet unowned var _tableView: NSTableView!

	private var instance: Instance!

	override var tableView: NSTableView!
	{
		return _tableView
	}

	override internal var cellIdentifier: NSUserInterfaceItemIdentifier
	{
		return NSUserInterfaceItemIdentifier("status")
	}

	override func set(results: ResultsType, instance: Instance)
	{
		self.instance = instance
		elements = results.statuses
	}

	override internal func populate(cell: NSTableCellView, for status: Status)
	{
		(cell as? StatusResultTableCellView)?.set(status: status, instance: instance)
	}

	override internal func makeSelection(for status: Status) -> SearchResultSelection
	{
		return .status(status)
	}
}

class StatusResultTableCellView: NSTableCellView
{
	/// Some of this code is just copied from `StatusTableCellView` and should probably be abstracted out

	private func fontService() -> FontService
	{
		return FontService(font: MastonautPreferences.instance.statusFont)
	}

	@IBOutlet var avatarImageView: NSButton!
	@IBOutlet private unowned var authorNameButton: NSButton!
	@IBOutlet private unowned var authorAccountLabel: NSTextField!
	@IBOutlet var statusLabel: AttributedLabel!

	@IBOutlet var contentWarningContainer: BorderView!
	@IBOutlet var contentWarningLabel: AttributedLabel!
	@IBOutlet var warningButton: NSButton!

	/// this used to be `RefreshingFormattedTextField`, but that type doesn't seem to be used anywhere else
	@IBOutlet var timeLabel: NSTextField!
	@IBOutlet var hasPoll: NSTextField!

	@IBOutlet var attachments: NSTextField!

	@IBOutlet var mainContentStackView: NSStackView!

	private(set) var hasSpoiler: Bool = false

	var isContentHidden: Bool
	{
		return warningButton.state == .off
	}

	private lazy var spoilerCoverView: NSView =
	{
		let coverView = CoverView(backgroundColor: NSColor(named: "SpoilerCoverBackground")!,
		                          message: 🔠("Content Hidden: Click warning button below to toggle display."))
		coverView.target = self
		coverView.action = #selector(toggleContentVisibility)
		return coverView
	}()

	override func awakeFromNib()
	{
		super.awakeFromNib()

		timeLabel.formatter = RelativeDateFormatter.shared

		// https://github.com/chucker/Mastonaut/issues/79 unclear why needed (otherwise set to pink)
		contentWarningLabel.backgroundColor = NSColor.clear
		statusLabel.backgroundColor = NSColor.clear
	}

	func loadAccountAvatar(for status: Status, completion: @escaping (NSImage) -> Void)
	{
		AppDelegate.shared.avatarImageCache.fetchImage(account: status.account)
		{ result in
			switch result
			{
			case .inCache(let avatarImage):
				assert(Thread.isMainThread)
				completion(avatarImage)
			case .loaded(let avatarImage):
				DispatchQueue.main.async { completion(avatarImage) }
			case .noImage:
				DispatchQueue.main.async { completion(#imageLiteral(resourceName: "missing")) }
			}
		}
	}

	func set(status: Status, instance: Instance)
	{
		loadAccountAvatar(for: status)
		{ [weak avatarImageView] in
			if let avatarImageView
			{
				avatarImageView.image = $0
			}
		}

		authorNameButton.set(stringValue: status.authorName,
		                     applyingAttributes: fontService().authorAttributes(),
		                     applyingEmojis: status.account.cacheableEmojis)

		authorAccountLabel.stringValue = status.account.uri(in: instance)

		var statusString: NSAttributedString

		if status.attributedContent.length > 500
		{
			let truncatedString = status.attributedContent.attributedSubstring(from: NSMakeRange(0, 100)).mutableCopy() as! NSMutableAttributedString
			truncatedString.append(NSAttributedString(string: "…"))
			statusString = truncatedString
		}
		else
		{
			statusString = status.attributedContent
		}

		statusLabel.set(attributedStringValue: statusString,
		                applyingAttributes: fontService().statusAttributes(),
		                applyingEmojis: status.cacheableEmojis)

		if status.mediaAttachments.count > 0
		{
			attachments.isHidden = false
			attachments.stringValue = 🔠("%@ attachments", String(status.mediaAttachments.count))
		}
		else
		{
			attachments.isHidden = true
		}

		hasPoll.isHidden = status.poll == nil

		timeLabel.objectValue = status.createdAt
		timeLabel.toolTip = DateFormatter.longDateFormatter.string(from: status.createdAt)

		if status.spoilerText.isEmpty
		{
			hasSpoiler = false

			warningButton.isHidden = true
			contentWarningContainer.isHidden = true
		}
		else
		{
			hasSpoiler = true

			warningButton.isHidden = false
			contentWarningLabel.set(attributedStringValue: status.attributedSpoiler,
			                        applyingAttributes: fontService().statusAttributes(),
			                        applyingEmojis: status.cacheableEmojis)
			installSpoilerCover()
			contentWarningContainer.isHidden = false
		}
	}

	override func prepareForReuse()
	{
		super.prepareForReuse()

		removeSpoilerCover()
	}

	@objc func toggleContentVisibility()
	{
		guard hasSpoiler else { return }

		setContentHidden(!isContentHidden)
	}

	func setContentHidden(_ hideContent: Bool)
	{
		let coverView = spoilerCoverView

		warningButton.state = hideContent ? .off : .on

		statusLabel.animator().alphaValue = hideContent ? 0 : 1
		statusLabel.setAccessibilityEnabled(!hideContent)
		coverView.setHidden(!hideContent, animated: true)
		statusLabel.isEnabled = !hideContent
	}

	internal func installSpoilerCover()
	{
		removeSpoilerCover()

		let spoilerCover = spoilerCoverView
		addSubview(spoilerCover)

		let spacing = mainContentStackView.spacing

		NSLayoutConstraint.activate([
			spoilerCover.topAnchor.constraint(equalTo: contentWarningContainer.bottomAnchor, constant: spacing),
			spoilerCover.bottomAnchor.constraint(equalTo: mainContentStackView.bottomAnchor, constant: 2),
			spoilerCover.leftAnchor.constraint(equalTo: mainContentStackView.leftAnchor),
			spoilerCover.rightAnchor.constraint(equalTo: mainContentStackView.rightAnchor)
		])
	}

	internal func removeSpoilerCover()
	{
		spoilerCoverView.removeFromSuperview()
	}

	@IBAction private func interactionButtonClicked(_ sender: NSButton)
	{
		switch (sender, sender.state)
		{
		case (warningButton, .on):
			setContentHidden(false)

		case (warningButton, .off):
			setContentHidden(true)

		default: break
		}
	}
}
