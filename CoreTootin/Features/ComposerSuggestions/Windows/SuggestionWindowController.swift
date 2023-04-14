//
//  SuggestionWindowController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 10.06.19.
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
import DSFSparkline
import MastodonKit

public class SuggestionWindowController: NSWindowController
{
	@IBOutlet private(set) unowned var tableView: NSTableView!

	private var accountSuggestions: [AccountSuggestionProtocol]?
	private var hashtagSuggestions: [HashtagSuggestionProtocol]?

	public weak var imagesProvider: AccountSuggestionWindowImagesProvider?

	public var isWindowVisible: Bool
	{
		return window?.isVisible ?? false
	}

	var insertSuggestionBlock: ((SuggestionContainer) -> Void)?

	convenience init(mode: SuggestionMode)
	{
		switch mode
		{
		case .mention:
			self.init(windowNibName: NSNib.Name("AccountSuggestionWindowController"))
		case .hashtag:
			self.init(windowNibName: NSNib.Name("HashtagSuggestionWindowController"))
		}
	}

	override public func windowDidLoad()
	{
		super.windowDidLoad()

		tableView.target = self
		tableView.doubleAction = #selector(didDoubleClickTableView(_:))
	}

	public func positionWindow(under textRect: NSRect)
	{
		let suggestionsCount = accountSuggestions?.count ?? hashtagSuggestions?.count

		if let suggestionsCount, let tableView
		{
			let visibleCount = CGFloat(min(suggestionsCount, 8))
			let bestHeight = visibleCount * (tableView.rowHeight + tableView.intercellSpacing.height)

			var width: Double

			switch windowNibName
			{
			case "AccountSuggestionWindowController":
				width = 482
			case "HashtagSuggestionWindowController":
				width = 272
			default:
				return
			}

			window?.setContentSize(NSSize(width: width, height: bestHeight))
		}

		window?.setFrameTopLeftPoint(NSPoint(x: textRect.minX - 30, y: textRect.minY))
	}

	func set(suggestionContainers: [SuggestionContainer])
	{
		guard !suggestionContainers.isEmpty else { return }

		switch suggestionContainers[0]
		{
		case .hashtag:
			accountSuggestions = nil
			hashtagSuggestions = suggestionContainers.map
			{ if case let .hashtag(hashtag) = $0
				{ return hashtag }
				else { fatalError() }
			}
		case .mention:
			accountSuggestions = suggestionContainers.map
			{ if case let .mention(mention) = $0
				{ return mention }
				else { fatalError() }
			}
			hashtagSuggestions = nil
		}

		tableView?.reloadData()
		tableView?.selectRowAndScrollToVisible(0)
	}

	public func insertSelectedSuggestion()
	{
		let currentSelection = tableView.selectedRow

		guard
			let block = insertSuggestionBlock
		else { return }

		if let suggestions = accountSuggestions, (0..<suggestions.count).contains(currentSelection)
		{
			block(SuggestionContainer.mention(suggestions[currentSelection]))
		}
		else if let suggestions = hashtagSuggestions, (0..<suggestions.count).contains(currentSelection)
		{
			block(SuggestionContainer.hashtag(suggestions[currentSelection]))
		}
	}

	@objc func didDoubleClickTableView(_ sender: Any)
	{
		insertSelectedSuggestion()
	}

	@IBAction func selectNext(_ sender: Any?)
	{
		guard let suggestions: [Any] = accountSuggestions ?? hashtagSuggestions else { return }
		let currentSelection = tableView.selectedRow

		guard (0..<suggestions.count).contains(currentSelection + 1)
		else
		{
			tableView.selectRowAndScrollToVisible(0)
			return
		}

		tableView.selectRowAndScrollToVisible(currentSelection + 1)
	}

	@IBAction func selectPrevious(_ sender: Any?)
	{
		guard let suggestions: [Any] = accountSuggestions ?? hashtagSuggestions else { return }
		let currentSelection = tableView.selectedRow

		print("suggestions: \(suggestions.count) acc: \(accountSuggestions?.count ?? 0) has: \(hashtagSuggestions?.count ?? 0)")

		guard currentSelection > 0
		else
		{
			tableView.selectRowAndScrollToVisible(suggestions.count - 1)
			return
		}

		tableView.selectRowAndScrollToVisible(currentSelection - 1)
	}
}

extension SuggestionWindowController: NSTableViewDataSource
{
	public func numberOfRows(in tableView: NSTableView) -> Int
	{
		if let accountSuggestions
		{
			return accountSuggestions.count
		}
		else if let hashtagSuggestions
		{
			return hashtagSuggestions.count
		}

		return 0
	}
}

extension SuggestionWindowController: NSTableViewDelegate
{
	public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView?
	{
		let identifier = NSUserInterfaceItemIdentifier("RedrawsOnSelectTableRowView")

		guard let rowView = tableView.makeView(withIdentifier: identifier, owner: nil) as! RedrawsOnSelectTableRowView?
		else
		{
			let rowView = RedrawsOnSelectTableRowView()
			rowView.identifier = identifier
			rowView.tableView = tableView
			return rowView
		}

		return rowView
	}

	public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
	{
		guard let identifier = tableColumn?.identifier else { return nil }

		let view = tableView.makeView(withIdentifier: identifier, owner: nil)

		if let suggestion = accountSuggestions?[row], let cellView = view as? NSTableCellView
		{
			switch identifier.rawValue
			{
			case "avatar":
				cellView.imageView?.image = #imageLiteral(resourceName: "missing.png")
				guard let imageURL = suggestion.imageUrl else { break }
				imagesProvider?.suggestionWindow(self, imageForSuggestionUsingURL: imageURL)
				{
					[weak self] image in
					guard let image = image else { return }
					DispatchQueue.main.async
					{
						self?.updateImage(for: suggestion, originalIndex: row, image: image)
					}
				}

			case "suggestion":
				cellView.textField?.stringValue = suggestion.text

			case "displayName":
				cellView.textField?.stringValue = suggestion.displayName

			default:
				break
			}
		}

		if let suggestion = hashtagSuggestions?[row], let cellView = view as? NSTableCellView
		{
			switch identifier.rawValue
			{
			case "name":
				cellView.textField?.stringValue = suggestion.text

			default:
				break
			}
		}

		if let suggestion = hashtagSuggestions?[row],
		   identifier.rawValue == "history",
		   let cellView = view as? SparklineTableCellView
		{
			if cellView.dataSource == nil || cellView.maxUses == nil
			{
				guard !suggestion.uses.isEmpty,
				      let maxUses = suggestion.uses.max() else { return view }

				// MAYBE maxUses should be across all search results?

				cellView.maxUses = maxUses

				cellView.dataSource = DSFSparkline.DataSource(values: suggestion.uses.map { CGFloat($0) },
				                                              range: 0 ... CGFloat(maxUses))
			}

			cellView.redraw(isSelected: tableView.selectedRow == row)
		}

		return view
	}

	private func updateImage(for suggestion: AccountSuggestionProtocol, originalIndex: Int, image: NSImage)
	{
		guard
			let suggestions = accountSuggestions,
			originalIndex < suggestions.count,
			suggestions[originalIndex].imageUrl == suggestion.imageUrl
		else { return }

		let view = tableView.view(atColumn: 0, row: originalIndex, makeIfNecessary: false)

		if let cellView = view as? NSTableCellView
		{
			cellView.imageView?.image = image
		}
	}
}

private extension NSTableView
{
	func selectRowAndScrollToVisible(_ row: Int)
	{
		selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
		scrollRowToVisible(row)
	}
}

@objc public protocol AccountSuggestionWindowImagesProvider: AnyObject
{
	func suggestionWindow(_ windowController: SuggestionWindowController,
	                      imageForSuggestionUsingURL: URL,
	                      completion: @escaping (NSImage?) -> Void)
}
