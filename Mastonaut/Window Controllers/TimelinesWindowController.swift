//
//  TimelinesWindowController.swift
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

class TimelinesWindowController: NSWindowController, UserPopUpButtonDisplaying, ToolbarWindowController
{
	// MARK: Outlets
	@IBOutlet private weak var newColumnMenu: NSMenu!

	// MARK: Services
	private unowned let accountsService = AppDelegate.shared.accountsService
	private unowned let instanceService = AppDelegate.shared.instanceService

	// MARK: KVO Observers
	private var observations = [NSKeyValueObservation]()
	private var accountObservations = [NSKeyValueObservation]()

	// MARK: Toolbar Buttons
	internal lazy var toolbarContainerView: NSView? = makeToolbarContainerView()
	internal var currentUserPopUpButton: NSPopUpButton = makeAccountsPopUpButton()
	private var statusComposerSegmentedControl: NSSegmentedControl = makeStatusComposerSegmentedControl()
	private var newColumnSegmentedControl: NSSegmentedControl = makeNewColumnSegmentedControl()
	private var userPopUpButtonController: UserPopUpButtonSubcontroller!
	private var popUpButtonConstraints = [NSLayoutConstraint]()
	private let columnPopUpButtonMap = NSMapTable<NSViewController, NSPopUpButton>(keyOptions: .weakMemory,
																				   valueOptions: .weakMemory)

	// MARK: Toolbar Sidebar Controls
	private var sidebarNavigationSegmentedControl: NSSegmentedControl = makeSidebarNavigationSegmentedControl()
	private var sidebarTitleViewController = SidebarTitleViewController()
	private var sidebarTitleViewCenterXConstraint: NSLayoutConstraint? = nil
	private var closeSidebarSegmentedControl: NSSegmentedControl?

	// MARK: Sidebar
	private lazy var sidebarSubcontroller = SidebarSubcontroller(sidebarContainer: self,
																 navigationControl: sidebarNavigationSegmentedControl,
																 navigationStack: nil)

	internal var sidebarViewController: SidebarViewController? {
		get { return timelinesSplitViewController.sidebarViewController }
		set { timelinesSplitViewController.sidebarViewController = newValue }
	}

	// MARK: Child View Controllers
	private var placeholderViewController: NSViewController?
	private var searchWindowController: NSWindowController?

	// MARK: Lifecycle Support
	private var preservedWindowFrameStack: Stack<CGRect> = []

	var currentInstance: Instance? {
		didSet {
			if let sidebarMode = self.sidebarSubcontroller.navigationStack?.currentItem,
				self.sidebarViewController == nil {
				let oldStack = preservedWindowFrameStack
				self.sidebarSubcontroller.installSidebar(mode: sidebarMode)
				preservedWindowFrameStack = oldStack
			}
		}
	}

	private(set) var client: ClientType? = nil {
		didSet {
			guard AppDelegate.shared.appIsReady else { return }

			timelinesViewController.columnViewControllers.forEach({ $0.client = client })
			revalidateSidebarAccountReference()
		}
	}

	internal var currentUser: UUID? {
		get { return currentAccount?.uuid }
		set { currentAccount = newValue.flatMap({ accountsService.account(with: $0) }) }
	}

	internal var currentAccount: AuthorizedAccount? = nil {
		didSet {
			let hasUser: Bool

			if let currentAccount = self.currentAccount {
				hasUser = true
				let client = Client.create(for: currentAccount)

				if let window = self.window {
					if let instance = currentAccount.baseDomain {
						window.title = "@\(currentAccount.username!) — \(instance)"
					}
					else {
						window.title = "@\(currentAccount.username!)"
					}
				}

				removePlaceholderIfInstalled()
				updateUserPopUpButton()

				instanceService.instance(for: currentAccount) {
					[weak self] (instance) in
					DispatchQueue.main.async {
							self?.client = client
							self?.currentInstance = instance
						}
				}

				accountObservations.observe(currentAccount, \.bookmarkedTags) {
					(_, _) in AppDelegate.shared.updateAccountsMenu()
				}
			}
			else {
				hasUser = false
				client = nil
				currentInstance = nil
				accountObservations.removeAll()
				sidebarSubcontroller.uninstallSidebar()
				installPlaceholder()
				window?.title = 🔠("Mastonaut — No Account Selected")
			}

			statusComposerSegmentedControl.isHidden = !hasUser
			newColumnSegmentedControl.isHidden = !hasUser
			timelinesViewController.columnViewControllers.forEach({ columnPopUpButtonMap.object(forKey: $0)?.isHidden = !hasUser })
			columnPopUpButtonMap.objectEnumerator()?.forEach({ ($0 as? NSControl)?.isHidden = !hasUser })

			invalidateRestorableState()

			if window?.isKeyWindow == true {
				AppDelegate.shared.updateAccountsMenu()
			}
		}
	}

	var hasNotificationsColumn: Bool {
		for controller in timelinesViewController.columnViewControllers {
			if case .some(ColumnMode.notifications) = controller.modelRepresentation {
				return true
			}
		}

		return false
	}

	private var timelinesSplitViewController: TimelinesSplitViewController {
		return contentViewController as! TimelinesSplitViewController
	}

	private var timelinesViewController: TimelinesViewController {
		return timelinesSplitViewController.children.first as! TimelinesViewController
	}

	private lazy var accountMenuItems: [NSMenuItem] = {
		return [
			NSMenuItem(title: 🔠("View Profile"),
					   action: #selector(showUserProfile(_:)),
					   keyEquivalent: ""),
			NSMenuItem(title: 🔠("Open Profile in Browser"),
					   action: #selector(openUserProfileInBrowser(_:)),
					   keyEquivalent: ""),
			NSMenuItem(title: 🔠("View Favorites"),
					   action: #selector(showUserFavorites(_:)),
					   keyEquivalent: "F").with(modifierMask: [.command, .shift]),
			.separator()
		]
	}()

	// MARK: Window Controller Lifecycle

	func prepareAsEmptyWindow() {
		if Preferences.newWindowAccountMode == .pickFirstOne, let account = accounts.first {
			currentAccount = account
		}
		else {
			currentAccount = nil
		}

		appendColumnIfFitting(model: ColumnMode.timeline)
	}

	override func encodeRestorableState(with coder: NSCoder) {
		let columnModels = timelinesViewController.columnViewControllers.compactMap({ $0.modelRepresentation })
		let encodedColumnModels = columnModels.map({ $0.rawValue }).joined(separator: ";")

		coder.encode(currentAccount?.uuid, forKey: CodingKeys.currentUser)
		coder.encode(encodedColumnModels, forKey: CodingKeys.columns)
		coder.encode(preservedWindowFrameStack.map({ NSValue(rect: $0) }), forKey: CodingKeys.preservedWindowFrameStack)

		if let navigationStack = sidebarSubcontroller.navigationStack {
			// HOTFIX: Swift classes with parameter types do not encode properly in *Release*
			// Since we know the type in advance, we use a separate archiver for the navigation stack which skips
			// the class name level and encodes only the internals.
			let encoder = NSKeyedArchiver(requiringSecureCoding: false)
			navigationStack.encode(with: encoder)
			coder.encode(encoder.encodedData, forKey: CodingKeys.sidebarNavigationStack)

//			coder.encode(navigationStack, forKey: CodingKeys.sidebarNavigationStack)
		}
	}

	override func restoreState(with coder: NSCoder) {
		if let uuid: UUID = coder.decodeObject(forKey: CodingKeys.currentUser),
			let account = accountsService.account(with: uuid) {
			currentAccount = account
		}
		else {
			currentAccount = nil
		}

		if let encodedColumnModels: String = coder.decodeObject(forKey: CodingKeys.columns) {
			let columnModels = encodedColumnModels.split(separator: ";")
												  .compactMap({ ColumnMode(rawValue: String($0)) })

			for model in columnModels {
				appendColumnIfFitting(model: model, expand: false)
			}
		}

		if let frameStack: [NSValue] = coder.decodeObject(forKey: CodingKeys.preservedWindowFrameStack) {
			preservedWindowFrameStack = Stack(frameStack.compactMap({ $0.rectValue }))
		}
		else {
			preservedWindowFrameStack = []
		}

		if timelinesViewController.columnViewControllers.isEmpty {
			// Fallback if no columns were installed from decoding
			appendColumnIfFitting(model: ColumnMode.timeline)
		}

		// HOTFIX: Swift classes with parameter types do not encode properly in *Release*
		// Since we know the type in advance, we use a separate archiver for the navigation stack which skips
		// the class name level and encodes only the internals.
//		if let stack: NavigationStack<SidebarMode> = coder.decodeObject(forKey: CodingKeys.sidebarNavigationStack)
		if let stackEncodedData: Data = coder.decodeObject(forKey: CodingKeys.sidebarNavigationStack) {
			let decoder = NSKeyedUnarchiver(forReadingWith: stackEncodedData)
			if let stack = NavigationStack<SidebarMode>(coder: decoder) {
				timelinesSplitViewController.preserveSplitViewSizeForNextSidebarInstall = true
				sidebarSubcontroller = SidebarSubcontroller(sidebarContainer: self,
															navigationControl: sidebarNavigationSegmentedControl,
															navigationStack: stack)
			}
		}

		updateUserPopUpButton()
	}

	override func windowDidLoad() {
		super.windowDidLoad()

		shouldCascadeWindows = true

		window?.restorationClass = TimelinesWindowRestoration.self

		newColumnSegmentedControl.setMenu(newColumnMenu, forSegment: 0)

		userPopUpButtonController = UserPopUpButtonSubcontroller(display: self)

		observations.observe(on: .main, timelinesViewController, \TimelinesViewController.columnViewControllersCount) {
				[weak self] timelinesViewController, change in
				self?.updateColumnsPopUpButtons(for: timelinesViewController.columnViewControllers)
				self?.newColumnSegmentedControl.setEnabled(timelinesViewController.canAppendStatusList, forSegment: 0)
				self?.invalidateRestorableState()
			}

		observations.observe(AppDelegate.shared, \AppDelegate.appIsReady) {
				[weak self] (appDelegate, _) in

				if appDelegate.appIsReady, let client = self?.client {
					self?.timelinesViewController.columnViewControllers.forEach({ $0.client = client })
					self?.revalidateSidebarAccountReference()
				}
			}

		guard let window = window else { return }

		window.backgroundColor = .timelineBackground
	}

	func handleDetach() {
		for _ in 0..<timelinesViewController.columnViewControllersCount {
			removeColumn(at: 0, contract: false)
		}
	}

	// MARK: UI Handling

	func updateUserPopUpButton() {
		userPopUpButtonController.updateUserPopUpButton()
	}

	func shouldChangeCurrentUser(to userUUID: UUID) -> Bool {
		return true
	}

	func redraft(status: Status) {
		let composerWindowController = AppDelegate.shared.statusComposerWindowController
		composerWindowController.showWindow(nil)
		composerWindowController.setUpAsRedraft(of: status, using: currentAccount)
	}

	func composeReply(for status: Status, sender: Any?) {
		let composerWindowController = AppDelegate.shared.statusComposerWindowController
		composerWindowController.showWindow(sender)
		composerWindowController.setupAsReply(to: status, using: currentAccount, senderWindowController: self)
	}

	func composeMention(userHandle: String, directMessage: Bool) {
		let composerWindowController = AppDelegate.shared.statusComposerWindowController
		composerWindowController.showWindow(nil)

		composerWindowController.setupAsMention(handle: userHandle, using: currentAccount, directMessage: directMessage)
	}

	func installPlaceholder() {
		guard let contentView = contentViewController?.view, placeholderViewController == nil else { return }

		let accounts = accountsService.authorizedAccounts
		let viewController: NSViewController

		if accounts.isEmpty {
			// Show welcome placeholder
			viewController = WelcomePlaceholderController()
		}
		else {
			// Show account picker placeholder
			viewController = AccountsPlaceholderController()
		}

		contentView.subviews.forEach({ $0.isHidden = true })

		contentViewController?.addChild(viewController)
		contentView.addSubview(viewController.view)
		placeholderViewController = viewController

		NSLayoutConstraint.activate([
			contentView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
			contentView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
			contentView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
			contentView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
		])
	}

	func removePlaceholderIfInstalled() {
		placeholderViewController?.view.removeFromSuperview()
		placeholderViewController?.removeFromParent()
		placeholderViewController = nil

		contentViewController?.view.subviews.forEach({ $0.isHidden = false })
	}

	func presentSearchWindow() {
		let storyboard = NSStoryboard(name: "Search", bundle: .main)

		guard
			currentInstance != nil,
			let account = self.currentAccount,
			let client = self.client,
			let searchWindowController = storyboard.instantiateInitialController() as? SearchWindowController,
			let searchWindow = searchWindowController.window,
			let	timelinesWindow = self.window
		else {
			return
		}

		searchWindowController.set(client: client)
		searchWindowController.set(searchDelegate: self)

		AppDelegate.shared.instanceService.instance(for: account) {
				[weak self] (instance) in

				guard let instance = instance else { return }

				searchWindowController.set(instance: instance)
				self?.searchWindowController = searchWindowController

				timelinesWindow.beginSheet(searchWindow) {
						_ in self?.searchWindowController = nil
					}
			}
	}

	func adjustWindowFrame(adjustment: WindowSizeAdjustment) {
		guard
			let window = window,
			window.styleMask.contains(.fullScreen) == false,
			let screen = window.screen
		else { return }

		let originalWindowFrame = window.frame
		var frame = originalWindowFrame

		switch adjustment {
		case .nudgeIfClipped:
			let excessWidth = window.frame.maxX - screen.frame.maxX
			guard excessWidth > 0 else { return }
			frame.origin.x -= excessWidth

		case .expand(by: let extraWidth):
			preservedWindowFrameStack.push(originalWindowFrame)

			if originalWindowFrame.maxX + extraWidth <= screen.frame.maxX {
				frame.size.width = originalWindowFrame.width + extraWidth
			}
			else {
				frame.size.width = screen.frame.maxX - window.frame.origin.x
			}

			if let contentView = window.contentView {
				let contentFrame = window.contentRect(forFrameRect: frame)
				contentView.setFrameSize(contentFrame.size)
				contentView.layoutSubtreeIfNeeded()

				let difference = contentView.frame.width - contentFrame.width

				if difference > 0 {
					frame.origin.x -= difference
				}
			}

		case .contract(by: let extraWidth, let tryPoppingPreservedFrame):
			if tryPoppingPreservedFrame, let preservedFrame = preservedWindowFrameStack.popIfNotEmpty() {
				frame = preservedFrame
			}
			else {
				frame.size.width -= extraWidth
			}

		case .restorePreservedOriginIfPossible:
			if let preservedFrame = preservedWindowFrameStack.popIfNotEmpty() {
				frame.origin = preservedFrame.origin
			}
		}

		window.animator().setFrame(frame, display: false)
	}

	override func mouseDragged(with event: NSEvent) {
		super.mouseDragged(with: event)

		if preservedWindowFrameStack.isEmpty == false {
			preservedWindowFrameStack = []
		}
	}

	enum WindowSizeAdjustment {
		case expand(by: CGFloat)
		case nudgeIfClipped
		case contract(by: CGFloat, poppingPreservedFrameIfPossible: Bool)
		case restorePreservedOriginIfPossible
	}

	// MARK: ToolbarWindowController

	func didToggleToolbarShown(_ window: ToolbarWindow) {
		if window.toolbar?.isVisible == true {
			updateColumnsPopUpButtons(for: timelinesViewController.columnViewControllers)
		}
	}

	// MARK: Internal helper methods

	private func revalidateSidebarAccountReference() {
		if let accountBoundSidebar = timelinesSplitViewController.sidebarViewController as? AccountBound,
			let currentAccount = accountBoundSidebar.account,
			let instance = currentInstance,
			let client = client {
			ResolverService(client: client).resolve(account: currentAccount, activeInstance: instance) {
					[weak self] (result) in

					DispatchQueue.main.async {
							switch result {
							case .success(let account):
								if AppDelegate.shared.appIsReady {
									self?.timelinesSplitViewController.sidebarViewController?.client = client
								}
								accountBoundSidebar.setRecreatedAccount(account)
								self?.invalidateRestorableState()

							case .failure(let error):
								self?.displayError(error)
								self?.sidebarSubcontroller.uninstallSidebar()
							}
						}
				}
		}
		else {
			timelinesSplitViewController.sidebarViewController?.client = client
		}
	}

	private func installPersistentToolbarButtons(toolbarView: NSView) {
		var constraints: [NSLayoutConstraint] = []
		let contentView = timelinesViewController.mainContentView

		[currentUserPopUpButton, statusComposerSegmentedControl, newColumnSegmentedControl].forEach {
			toolbarView.addSubview($0)
			let referenceView = toolbarView.superview ?? toolbarView
			constraints.append(referenceView.centerYAnchor.constraint(equalTo: $0.centerYAnchor))
		}

		constraints.append(TrackingLayoutConstraint.constraint(trackingMaxXOf: contentView,
															   targetView: newColumnSegmentedControl,
															   containerView: toolbarView,
															   targetAttribute: .trailing,
															   containerAttribute: .leading)
													.with(priority: .defaultLow))

		constraints.append(contentsOf: [
			currentUserPopUpButton.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: 6),
			newColumnSegmentedControl.leadingAnchor.constraint(equalTo: statusComposerSegmentedControl.trailingAnchor,
															   constant: 8),
			toolbarView.trailingAnchor.constraint(greaterThanOrEqualTo: newColumnSegmentedControl.trailingAnchor, constant: 6)
		])

		NSLayoutConstraint.activate(constraints)
	}

	private func updateColumnsPopUpButtons(for columnViewControllers: [ColumnViewController]) {
		guard let toolbarView = self.toolbarContainerView?.superview else { return }

		NSLayoutConstraint.deactivate(popUpButtonConstraints)
		popUpButtonConstraints.removeAll()

		let allSelectableModels = ColumnMode.allItems
		let takenModels = columnViewControllers.compactMap({ $0.modelRepresentation as? ColumnMode })

		var previousButton = currentUserPopUpButton

		// Install column buttons
		for (index, column) in columnViewControllers.enumerated() {
			guard let popUpButton = columnPopUpButtonMap.object(forKey: column) else {
				continue
			}

			guard let currentModel = column.modelRepresentation as? ColumnMode else {
				continue
			}

			let menu = NSMenu(title: "")
			var items: [NSMenuItem] = allSelectableModels.filter({ !takenModels.contains($0) })
														 .map({ $0.makeMenuItemForChanging(with: self, columnId: index) })

			items.append(currentModel.makeMenuItemForChanging(with: self, columnId: index))
			items.sort(by: { $0.columnModel! < $1.columnModel! })

			items.append(.separator())

			let reloadColumnItem = NSMenuItem()
			reloadColumnItem.title = 🔠("Reload this Column")
			reloadColumnItem.target = self
			reloadColumnItem.representedObject = index
			reloadColumnItem.action = #selector(TimelinesWindowController.reloadColumn(_:))
			items.append(reloadColumnItem)

			if index > 0 {
				let removeColumnItem = NSMenuItem()
				removeColumnItem.title = 🔠("Remove this Column")
				removeColumnItem.target = self
				removeColumnItem.representedObject = index
				removeColumnItem.action = #selector(TimelinesWindowController.removeColumn(_:))
				items.append(removeColumnItem)
			}

			menu.setItems(items)
			popUpButton.menu = menu
			popUpButton.tag = index
			popUpButton.select(menu.item(withRepresentedObject: currentModel))

			popUpButtonConstraints.append(TrackingLayoutConstraint
											.constraint(trackingMidXOf: column.view,
														targetView: popUpButton,
														containerView: toolbarView,
														targetAttribute: .centerX,
														containerAttribute: .leading)
											.with(priority: .defaultLow + 248))

			popUpButtonConstraints.append(popUpButton.leadingAnchor.constraint(
											greaterThanOrEqualTo: previousButton.trailingAnchor,
											constant: 8))

			previousButton = popUpButton
		}

		if previousButton != currentUserPopUpButton {
			popUpButtonConstraints.append(statusComposerSegmentedControl.leadingAnchor.constraint(
											greaterThanOrEqualTo: previousButton.trailingAnchor,
											constant: 8))
		}

		newColumnMenu.setItems(ColumnMode.allItems.filter({ !takenModels.contains($0)} )
												  .map({ $0.makeMenuItemForAdding(with: self) }))

		newColumnSegmentedControl.setEnabled(!newColumnMenu.items.isEmpty, forSegment: 0)

		NSLayoutConstraint.activate(popUpButtonConstraints)
	}

	// MARK: - Keyboard Navigation

	override func moveRight(_ sender: Any?) {
		timelinesViewController.makeNextColumnFirstResponder()
	}
	
	override func moveDown(_ sender: Any?) {
		timelinesViewController.makeNextColumnFirstResponder()
	}
	
	override func moveUp(_ sender: Any?) {
		timelinesViewController.makeNextColumnFirstResponder()
	}

	override func moveLeft(_ sender: Any?) {
		timelinesViewController.makePreviousColumnFirstResponder()
	}
}

extension TimelinesWindowController: SidebarContainer
{
	func willInstallSidebar(viewController: NSViewController) {
		if let currentWindowFrame = window?.frame {
			preservedWindowFrameStack.push(currentWindowFrame)
		}

		contentViewController?.addChild(viewController)
	}

	func didInstallSidebar(viewController: NSViewController, with mode: SidebarMode) {
		guard
			let toolbarView = self.toolbarContainerView,
			closeSidebarSegmentedControl?.superview == nil,
			sidebarNavigationSegmentedControl.superview == nil,
			let titleMode = sidebarViewController?.titleMode
		else {
			invalidateRestorableState()
			return
		}

		let navigationControl = sidebarNavigationSegmentedControl

		let closeSidebarButton = makeCloseSidebarButton()
		toolbarView.addSubview(closeSidebarButton)
		toolbarView.addSubview(navigationControl)

		let titleView = sidebarTitleViewController.view
		sidebarTitleViewController.titleMode = titleMode
		toolbarView.addSubview(titleView)

		let leadingConstraint = TrackingLayoutConstraint.constraint(
			trackingMaxXOf: timelinesViewController.mainContentView,
			offset: timelinesSplitViewController.splitView.dividerThickness,
			targetView: navigationControl,
			containerView: toolbarView,
			targetAttribute: .leading,
			containerAttribute: .leading
		).with(priority: .defaultLow + 1)

		let centerConstraint = TrackingLayoutConstraint.constraint(
			trackingMidXOf: sidebarViewController!.view.firstParentViewInsideSplitView(),
			offset: timelinesSplitViewController.splitView.dividerThickness,
			targetView: titleView,
			containerView: toolbarView,
			targetAttribute: .centerX,
			containerAttribute: .leading
		).with(priority: .defaultLow + 1)

		sidebarTitleViewCenterXConstraint = centerConstraint

		NSLayoutConstraint.activate([
			toolbarView.trailingAnchor.constraint(equalTo: closeSidebarButton.trailingAnchor, constant: 8),
			leadingConstraint,
			navigationControl.leadingAnchor.constraint(greaterThanOrEqualTo: newColumnSegmentedControl.trailingAnchor,
													   constant: 10),

			titleView.leadingAnchor.constraint(greaterThanOrEqualTo: navigationControl.trailingAnchor, constant: 8),
			closeSidebarButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleView.trailingAnchor, constant: 8),
			centerConstraint,

			toolbarView.centerYAnchor.constraint(equalTo: closeSidebarButton.centerYAnchor),
			toolbarView.centerYAnchor.constraint(equalTo: navigationControl.centerYAnchor),
			toolbarView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor)
		])

		closeSidebarSegmentedControl = closeSidebarButton

		invalidateRestorableState()
	}

	func didUpdateSidebar(viewController: NSViewController, previousViewController: NSViewController, with mode: SidebarMode) {
		guard let toolbarView = self.toolbarContainerView,
			  let sidebarViewController = self.sidebarViewController
		else { return }

		sidebarTitleViewController.titleMode = sidebarViewController.titleMode

		sidebarTitleViewCenterXConstraint?.isActive = false

		let centerConstraint = TrackingLayoutConstraint.constraint(
			trackingMidXOf: sidebarViewController.view.firstParentViewInsideSplitView(),
			offset: timelinesSplitViewController.splitView.dividerThickness,
			targetView: sidebarTitleViewController.view,
			containerView: toolbarView,
			targetAttribute: .centerX,
			containerAttribute: .leading
		).with(priority: .defaultLow + 1)
		centerConstraint.isActive = true

		sidebarTitleViewCenterXConstraint = centerConstraint

		previousViewController.removeFromParent()

		invalidateRestorableState()
	}

	func willUninstallSidebar(viewController: NSViewController) {
		adjustWindowFrame(adjustment: .restorePreservedOriginIfPossible)
	}

	func didUninstallSidebar(viewController: NSViewController) {
		sidebarNavigationSegmentedControl.removeFromSuperview()
		sidebarTitleViewController.view.removeFromSuperview()
		closeSidebarSegmentedControl?.removeFromSuperview()
		closeSidebarSegmentedControl = nil

		viewController.removeFromParent()

		invalidateRestorableState()
	}

	func reloadSidebarTitleMode() {
		sidebarTitleViewController.titleMode = sidebarViewController?.titleMode ?? .none
	}

	private enum CodingKeys: String {
		case currentUser
		case columns
		case sidebarNavigationStack
		case preservedWindowFrameStack
	}
}

extension TimelinesWindowController
{
	func appendColumnIfFitting(model: ColumnModel, expand: Bool = true) {
		guard
			let columnViewController = timelinesViewController.appendColumnIfFitting(model: model, expand: expand)
		else {
			return
		}

		columnViewController.client = AppDelegate.shared.appIsReady ? client : nil

		guard let toolbarView = self.toolbarContainerView else {
			return
		}

		let popUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
		popUpButton.bezelStyle = .texturedRounded
		popUpButton.translatesAutoresizingMaskIntoConstraints = false
		popUpButton.isHidden = currentUser == nil
		popUpButton.setContentCompressionResistancePriority(.defaultLow + 249, for: .horizontal)
		toolbarView.addSubview(popUpButton)

		let anyColumnPopUpButton = columnPopUpButtonMap.objectEnumerator()?.nextObject() as? NSPopUpButton

		columnPopUpButtonMap.setObject(popUpButton, forKey: columnViewController)

		NSLayoutConstraint.activate([
			toolbarView.centerYAnchor.constraint(equalTo: popUpButton.centerYAnchor),
			popUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).with(priority: .defaultHigh)
		])

		if let otherPopUpButton = anyColumnPopUpButton {
			otherPopUpButton.widthAnchor.constraint(equalTo: popUpButton.widthAnchor).isActive = true
		}
	}

	func replaceColumn(at columnIndex: Int, with newViewController: ColumnViewController) {
		let oldViewController = timelinesViewController.replaceColumn(at: columnIndex, with: newViewController)
		let popUpButton = columnPopUpButtonMap.object(forKey: oldViewController)!

		columnPopUpButtonMap.removeObject(forKey: oldViewController)
		columnPopUpButtonMap.setObject(popUpButton, forKey: newViewController)

		newViewController.client = client
	}

	func removeColumn(at columnIndex: Int, contract: Bool) {
		let columnViewController = timelinesViewController.removeColumn(at: columnIndex, contract: true)
		let popUpButton = columnPopUpButtonMap.object(forKey: columnViewController)!

		columnPopUpButtonMap.removeObject(forKey: columnViewController)
		popUpButton.removeFromSuperview()
	}

	func reloadColumn(at columnIndex: Int) {
		timelinesViewController.reloadColumn(at: columnIndex)
		updateColumnsPopUpButtons(for: timelinesViewController.columnViewControllers)
	}
}

extension TimelinesWindowController: NSWindowDelegate
{
	func windowDidChangeOcclusionState(_ notification: Foundation.Notification) {
		guard let occlusionState = window?.occlusionState else { return }
		timelinesViewController.columnViewControllers.forEach({ $0.containerWindowOcclusionStateDidChange(occlusionState)})
	}

	func windowWillClose(_ notification: Foundation.Notification) {
		sidebarSubcontroller.uninstallSidebar()
		AppDelegate.shared.detachTimelinesWindow(for: self)
	}
}

extension TimelinesWindowController: NSMenuItemValidation
{
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(TimelinesWindowController.dismissSidebar(_:)) {
			return sidebarSubcontroller.sidebarMode != nil
		}

		return true
	}
}

extension TimelinesWindowController: SearchViewDelegate
{
	func searchView(_ searchView: SearchViewController, userDidSelect selection: SearchResultSelection) {
		guard let instance = currentInstance else { return }

		switch selection {
		case .account(let account):
			presentInSidebar(SidebarMode.profile(uri: account.uri(in: instance), account: account))

		case .status(let status):
			presentInSidebar(SidebarMode.status(uri: status.resolvableURI, status: status))

		case .tag(let tagName):
			presentInSidebar(SidebarMode.tag(tagName))
		}
	}
}

extension TimelinesWindowController: AccountAuthorizationSource
{
	var sourceWindow: NSWindow? {
		return window
	}

	func prepareForAuthorization() {
	}

	func successfullyAuthenticatedUser(with userUUID: UUID) {
		currentAccount = accountsService.account(with: userUUID)
	}

	func finalizeAuthorization() {
		updateUserPopUpButton()
	}
}

extension TimelinesWindowController: AuthorizedAccountProviding
{
	var attachmentPresenter: AttachmentPresenting {
		return timelinesViewController
	}

	func presentInSidebar(_ mode: SidebarModel) {
		(mode as? SidebarMode).map { sidebarSubcontroller.installSidebar(mode: $0) }
	}

	func handle(linkURL: URL) {
		MastodonURLResolver.resolve(url: linkURL, knownTags: nil, source: self)
	}

	func handle(linkURL: URL, knownTags: [Tag]?) {
		MastodonURLResolver.resolve(url: linkURL, knownTags: knownTags, source: self)
	}
}

extension TimelinesWindowController // IBActions
{
	@IBAction func composeStatus(_ sender: Any?) {
		let composerWindowController = AppDelegate.shared.statusComposerWindowController

		guard let composerWindow = composerWindowController.window else { return }

		if let composerScreen = composerWindow.screen, let timelinesScreen = window?.screen,
			composerScreen !== timelinesScreen {
			// Move window to the inside of the screen where the current timelines window is
			composerWindow.setFrameOrigin(timelinesScreen.visibleFrame.origin)
		}

		composerWindowController.showWindow(sender)
		composerWindow.center()

		composerWindowController.currentAccount = currentAccount
	}

	@IBAction func showSearch(_ sender: Any?) {
		presentSearchWindow()
	}

	@IBAction func addColumnMode(_ sender: Any?) {
		if let menuItem = sender as? NSMenuItem, let newModel = menuItem.representedObject as? ColumnMode {
			appendColumnIfFitting(model: newModel)
		}
		else if let control = sender as? NSSegmentedControl, let event = NSApp.currentEvent {
			control.menu(forSegment: 0).map { NSMenu.popUpContextMenu($0, with: event, for: control) }
		}
	}

	@IBAction func changeColumnMode(_ sender: Any?) {
		guard
			let menuItem = sender as? NSMenuItem,
			let newModel = menuItem.representedObject as? ColumnMode
		else {
			return
		}

		let columnIndex = menuItem.tag
		let columnViewControllers = timelinesViewController.columnViewControllers

		guard columnIndex >= 0, columnIndex < columnViewControllers.count else {
			return
		}

		guard
			let selectableCurrentModel = columnViewControllers[columnIndex].modelRepresentation as? ColumnMode,
			selectableCurrentModel != newModel
			else {
			// Nothing to change
			return
		}

		replaceColumn(at: columnIndex, with: newModel.makeViewController())
	}

	@IBAction private func removeColumn(_ sender: Any?) {
		guard
			let menuItem = sender as? NSMenuItem,
			let columnIndex = menuItem.representedObject as? Int
			else {
			return
		}

		removeColumn(at: columnIndex, contract: true)
	}

	@IBAction private func reloadColumn(_ sender: Any?) {
		guard
			let menuItem = sender as? NSMenuItem,
			let columnIndex = menuItem.representedObject as? Int
			else {
			return
		}



		reloadColumn(at: columnIndex)
	}

	@IBAction private func dismissSidebar(_ sender: Any?) {
		sidebarSubcontroller.uninstallSidebar()
	}

	@IBAction private func showUserProfile(_ sender: Any?) {
		guard let accountURI = currentAccount?.uri else { return }
		sidebarSubcontroller.installSidebar(mode: SidebarMode.profile(uri: accountURI))
	}

	@IBAction private func showUserFavorites(_ sender: Any?) {
		sidebarSubcontroller.installSidebar(mode: SidebarMode.favorites)
	}

	@IBAction private func openUserProfileInBrowser(_ sender: Any?) {
		guard let account = currentAccount else { return }
		accountsService.details(for: account) {
			if case .success(let details) = $0 {
				DispatchQueue.main.async { NSWorkspace.shared.open(details.account.url) }
			}
		}
	}

	@IBAction func showTag(_ sender: Any?) {
		if let menuItem = sender as? NSMenuItem, let tagName = menuItem.representedObject as? String {
			presentInSidebar(SidebarMode.tag(tagName))
		}
	}
}

extension TimelinesWindowController: AccountsMenuProvider {
	private var accounts: [AuthorizedAccount] {
		return accountsService.authorizedAccounts
	}

	var accountsMenuItems: [NSMenuItem] {
		let accountItems = accounts.makeMenuItems(currentUser: currentAccount?.uuid,
												  action: #selector(UserPopUpButtonSubcontroller.selectAccount(_:)),
												  target: userPopUpButtonController,
												  emojiContainer: nil,
												  setKeyEquivalents: true).menuItems

		let bookmarkedTags = currentAccount?.bookmarkedTagsList ?? []
		var tagMenuItems: [NSMenuItem] = []

		if bookmarkedTags.isEmpty == false {
			tagMenuItems.append(.separator())

			let bookmarkedTagItems = MenuItemFactory.makeMenuItems(forTags: bookmarkedTags,
																   action: #selector(showTag(_:)),
																   target: self)

			let menu = NSMenu(title: "")
			menu.setItems(bookmarkedTagItems)
			tagMenuItems.append(NSMenuItem(title: 🔠("Bookmarked Tags"), submenu: menu))
			tagMenuItems.append(.separator())
		}

		return accountMenuItems + tagMenuItems + accountItems
	}
}

private extension TimelinesWindowController {
	func makeCloseSidebarButton() -> NSSegmentedControl {
		let button = NSSegmentedControl(images: [#imageLiteral(resourceName: "close_sidebar")], trackingMode: .momentary,
										target: self, action: #selector(dismissSidebar(_:)))
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}

	static func makeSidebarNavigationSegmentedControl() -> NSSegmentedControl {
		let segmentedControl = NSSegmentedControl(images: [NSImage(named: NSImage.goBackTemplateName)!,
														   NSImage(named: NSImage.goForwardTemplateName)!],
												  trackingMode: .momentary, target: nil, action: nil)
		segmentedControl.translatesAutoresizingMaskIntoConstraints = false
		return segmentedControl
	}

	static func makeAccountsPopUpButton() -> NSPopUpButton {
		let popUpButton = NonVibrantPopUpButton()
		popUpButton.bezelStyle = .texturedRounded
		popUpButton.translatesAutoresizingMaskIntoConstraints = false
		popUpButton.imagePosition = .imageOnly;
		return popUpButton
	}

	static func makeNewColumnSegmentedControl() -> NSSegmentedControl {
		let segmentedControl = NSSegmentedControl(images: [#imageLiteral(resourceName: "add_panel")], trackingMode: .momentary,
												  target: nil, action: #selector(addColumnMode(_:)))
		segmentedControl.translatesAutoresizingMaskIntoConstraints = false
		return segmentedControl
	}

	static func makeStatusComposerSegmentedControl() -> NSSegmentedControl {
		let segmentedControl = NSSegmentedControl(images: [#imageLiteral(resourceName: "compose")], trackingMode: .momentary,
												  target: nil, action: #selector(composeStatus(_:)))
		segmentedControl.translatesAutoresizingMaskIntoConstraints = false
		return segmentedControl
	}

	func makeToolbarContainerView() -> NSView? {
		guard let toolbarView: NSView = (window as? ToolbarWindow)?.toolbarView else {
			return nil
		}

		guard let toolbarItemsContainer = toolbarView.findSubview(withClassName: "NSToolbarItemViewer") else {
			installPersistentToolbarButtons(toolbarView: toolbarView)
			return toolbarView
		}

		installPersistentToolbarButtons(toolbarView: toolbarItemsContainer)
		return toolbarItemsContainer.superview!
	}
}
