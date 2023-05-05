//
//  TimelinesViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 19.02.19.
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

typealias ColumnViewController = NSViewController & ColumnPresentable

class TimelinesViewController: NSViewController
{
	@IBOutlet private weak var stackView: NSStackView!

	var timelinesSplitViewController: TimelinesSplitViewController {
		return parent as! TimelinesSplitViewController
	}

	var mainContentView: NSView
	{
		return stackView
	}

	internal var timelinesWindowController: TimelinesWindowController?
	{
		return view.window?.windowController as? TimelinesWindowController
	}

	internal var sidebarViewController: SidebarViewController?
	{
		return timelinesSplitViewController.sidebarViewController
	}

	// MARK: Column Management

	@objc dynamic var columnViewControllersCount: Int
	{
		return columnViewControllers.count
	}

	private(set) var columnViewControllers: [ColumnViewController] = []
	{
		willSet { willChangeValue(for: \TimelinesViewController.columnViewControllersCount) }
		didSet { didChangeValue(for: \TimelinesViewController.columnViewControllersCount) }
	}

	var canAppendStatusList: Bool
	{
		guard let screenSize = view.window?.screen?.frame.size else
		{
			return false
		}

		return screenSize.width >= ListViewControllerMinimumWidth * CGFloat(columnViewControllers.count + 1)
	}

	func appendColumnIfFitting(model: ColumnModel, expand: Bool = true) -> ColumnViewController?
	{
		guard canAppendStatusList else
		{
			return nil
		}

		let columnViewController = model.makeViewController()

		appendColumn(columnViewController, expand: expand)

		return columnViewController
	}

	private func appendColumn(_ columnViewController: ColumnViewController, expand: Bool)
	{
		if expand, Preferences.timelinesResizeMode == .expandWindowFirst,
			let windowController = timelinesWindowController,
			let statusListWidth = columnViewControllers.first?.view.frame.width
		{
			NSAnimationContext.runAnimationGroup()
				{
					context in

					context.allowsImplicitAnimation = true
					installColumn(columnViewController)

					let neededWidth = statusListWidth + stackView.spacing
					windowController.adjustWindowFrame(adjustment: .expand(by: neededWidth))
				}
		}
		else if columnViewControllers.isEmpty
		{
			// No animations in case this is the first column
			installColumn(columnViewController, animated: false)
		}
		else
		{
			NSAnimationContext.runAnimationGroup()
				{
					context in

					context.allowsImplicitAnimation = true
					installColumn(columnViewController)
				}
		}
	}

	private func installColumn(_ columnViewController: ColumnViewController, animated: Bool = true)
	{
		guard animated else
		{
			addChild(columnViewController)
			stackView.addArrangedSubview(columnViewController.view)
			columnViewControllers.append(columnViewController)
			return
		}

		let columnView = columnViewController.view
		columnView.isHidden = true
		addChild(columnViewController)
		stackView.addArrangedSubview(columnView)
		columnViewControllers.append(columnViewController)

		let helperConstraint = columnView.heightAnchor.constraint(equalTo: stackView.heightAnchor)
		helperConstraint.isActive = true

		stackView.layoutSubtreeIfNeeded()

		columnView.alphaValue = 0.0

		stackView?.setArrangedSubview(columnView, hidden: false, animated: true)
			{
				helperConstraint.isActive = false
				columnView.animator().alphaValue = 1.0
			}
	}

	func replaceColumn(at index: Int, with newColumnViewController: ColumnViewController) -> ColumnViewController
	{
		let oldColumnViewController = columnViewControllers[index]
		let newColumnView = newColumnViewController.view

		newColumnView.alphaValue = 0.0
		oldColumnViewController.view.animator().removeFromSuperview()
		oldColumnViewController.removeFromParent()
		addChild(newColumnViewController)
		stackView.insertArrangedSubview(newColumnView, at: index)

		newColumnView.animator().alphaValue = 1.0

		columnViewControllers[index] = newColumnViewController

		return oldColumnViewController
	}

	func removeColumn(at index: Int, contract: Bool) -> ColumnViewController
	{
		let oldColumnViewController = columnViewControllers[index]

		columnViewControllers.remove(at: index)

		if contract, Preferences.timelinesResizeMode == .expandWindowFirst,
			let windowController = timelinesWindowController,
			let statusListWidth = columnViewControllers.first?.view.frame.width
		{
			windowController.adjustWindowFrame(adjustment: .contract(by: statusListWidth + stackView.spacing,
																	 poppingPreservedFrameIfPossible: true))
		}

		stackView.setArrangedSubview(oldColumnViewController.view, hidden: true, animated: true)
			{
				oldColumnViewController.removeFromParent()
				oldColumnViewController.view.removeFromSuperview()
			}

		return oldColumnViewController
	}

	func reloadColumn(at index: Int) {
		columnViewControllers[index].reload()
	}

	// MARK: - Keyboard Navigation

	func makeNextColumnFirstResponder() {
		guard let window = view.window else { return }

		let firstResponder = window.firstResponder

		guard !(firstResponder is NSText) else { return }

		let columns: [BaseColumnViewController] = (columnViewControllers + [sidebarViewController]).compacted()

		if let firstResponder = firstResponder,
			let activeIndex = columns.firstIndex(where: { $0.mainResponder === firstResponder }) {

			let nextIndex = columns.index(after: activeIndex)

			if nextIndex == columns.endIndex {
				NSSound.beep()
				return
			}

			makeTimelineColumnFirstResponder(columns[nextIndex],
											 currentFocusRegion: columns[activeIndex].currentFocusRegion)
		} else if let column = columns.first {
			makeTimelineColumnFirstResponder(column, currentFocusRegion: nil)
		}
	}

	func makePreviousColumnFirstResponder() {
		guard let window = view.window else { return }

		let firstResponder = window.firstResponder

		guard !(firstResponder is NSText) else { return }

		let columns: [BaseColumnViewController] = (columnViewControllers + [sidebarViewController]).compacted()

		if let firstResponder = firstResponder,
			let activeIndex = columns.firstIndex(where: { $0.mainResponder === firstResponder }) {

			if activeIndex == columns.startIndex {
				NSSound.beep()
				return
			}

			let previousIndex = columns.index(before: activeIndex)

			makeTimelineColumnFirstResponder(columns[previousIndex],
											 currentFocusRegion: columns[activeIndex].currentFocusRegion)
		} else if let column = columns.first {
			makeTimelineColumnFirstResponder(column, currentFocusRegion: nil)
		}
	}

	private func makeTimelineColumnFirstResponder(_ columnViewController: BaseColumnViewController,
												  currentFocusRegion: NSRect?) {

		view.window?.makeFirstResponder(columnViewController.mainResponder)
		columnViewController.activateKeyboardNavigation(preferredFocusRegion: currentFocusRegion)
	}
}

extension TimelinesViewController: AttachmentPresenting
{
	func present(attachment: Attachment, from group: AttachmentGroup, senderWindow: NSWindow)
	{
		let controller = AppDelegate.shared.attachmentWindowController
		controller.set(attachment: attachment, attachmentGroup: group, senderWindow: senderWindow)
		controller.showWindow(nil)
	}
}

protocol BaseColumnViewController: NSViewController {
	var mainResponder: NSResponder { get }

	var currentFocusRegion: NSRect? { get }

	func activateKeyboardNavigation(preferredFocusRegion: NSRect?)
}

protocol ColumnModel {
	func makeViewController() -> ColumnViewController

	var rawValue: String { get }
}

protocol ColumnPresentable: BaseColumnViewController {

	var modelRepresentation: ColumnModel? { get }

	var client: ClientType? { get set }

	func reload()

	func containerWindowOcclusionStateDidChange(_ occlusionState: NSWindow.OcclusionState)
}

protocol SidebarModel
{
	func makeViewController(client: ClientType,
							currentAccount: AuthorizedAccount?,
							currentInstance: Instance) -> SidebarViewController

	var rawValue: String { get }
}

indirect enum SidebarTitleMode
{
	case none
	case title(NSAttributedString)
	case subtitle(title: NSAttributedString, subtitle: NSAttributedString)
	case buttons(SidebarTitleButtonsStateBindable, SidebarTitleMode)

	static func title(_ string: String) -> SidebarTitleMode
	{
		return .title(NSAttributedString(string: string))
	}

	static func subtitle(title: String, subtitle: String) -> SidebarTitleMode
	{
		return .subtitle(title: NSAttributedString(string: title), subtitle: NSAttributedString(string: subtitle))
	}
}

@objc class SidebarTitleButtonsStateBindable: NSObject
{
	// this is currently hardcoded to two buttons,
	// as we only use it for hashtags
	
	@objc dynamic var firstIcon: NSImage? = nil
	@objc dynamic var firstAccessibilityLabel: String? = nil
	@objc dynamic var firstAccessibilityTitle: String? = nil

	@objc func didClickFirstButton(_ sender: Any?)
	{
	}
	
	@objc dynamic var secondIcon: NSImage? = nil
	@objc dynamic var secondAccessibilityLabel: String? = nil
	@objc dynamic var secondAccessibilityTitle: String? = nil

	@objc func didClickSecondButton(_ sender: Any?)
	{
	}
}

protocol SidebarPresentable: BaseColumnViewController {

	var sidebarModelValue: SidebarModel { get }

	var client: ClientType? { get set }
	var titleMode: SidebarTitleMode { get }
	var mainResponder: NSResponder { get }

	func containerWindowOcclusionStateDidChange(_ occlusionState: NSWindow.OcclusionState)
}

extension SidebarPresentable
{
	func invalidateSidebarTitleMode()
	{
		(view.window?.windowController as? TimelinesWindowController)?.reloadSidebarTitleMode()
	}
}
