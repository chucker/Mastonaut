//
//  FilterEditorWindowController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 16.05.21.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2021 Bruno Philipe.
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
import MastodonKit

class FilterEditorWindowController: NSWindowController {

	override var windowNibName: NSNib.Name? {
		return "FilterEditorWindowController"
	}

	@IBOutlet weak var actionPopUpButton: NSPopUpButton!
	@IBOutlet weak var expirationDatePopUpButton: NSPopUpButton!
	@IBOutlet weak var expirationDatePicker: NSDatePicker!
	@IBOutlet weak var expirationDateLabel: NSTextField!
	@IBOutlet weak var saveButton: NSButton!

	@objc dynamic
	private(set) var canSave: ObjCBool = false

	@objc dynamic
	private(set) var filterPhrase: String = ""

	@objc dynamic
	private(set) var filterWholeWord: ObjCBool = false

	@objc dynamic
	private(set) var filterContextHome: ObjCBool = false

	@objc dynamic
	private(set) var filterContextNotifications: ObjCBool = false

	@objc dynamic
	private(set) var filterContextPublic: ObjCBool = false

	@objc dynamic
	private(set) var filterContextThread: ObjCBool = false

	@objc dynamic
	private(set) var filterContextAccount: ObjCBool = false

	var mode: Mode = .create {
		didSet {
			guard isWindowLoaded else { return }
			switch mode {
			case .create:
				resetBindings()
				saveButton.title = "Create Filter"
			case .edit(let filter):
				setBindings(filter: filter)
				saveButton.title = "Save Changes"
			}
		}
	}

	var dismissBlock: (() -> Void)? = nil

	var saveBlock: ((UserFilter, Mode) -> Void)? = nil

	private var observations: [NSKeyValueObservation] = []

	override func windowDidLoad() {
		super.windowDidLoad()

		observations.append(observe(\.filterPhrase) { [weak self] _, _ in
			self?.updateCanSave()
		})

		expirationDatePicker.isHidden = true
		expirationDateLabel.isHidden = true

		switch mode {
		case .create:
			resetBindings()
		case .edit(let filter):
			setBindings(filter: filter)
		}
	}

	private func setBindings(filter: UserFilter) {
		filterPhrase = filter.phrase
		filterWholeWord = ObjCBool(filter.wholeWord)
		filterContextHome = ObjCBool(filter.context.contains(.home))
		filterContextNotifications = ObjCBool(filter.context.contains(.notifications))
		filterContextPublic = ObjCBool(filter.context.contains(.public))
		filterContextThread = ObjCBool(filter.context.contains(.thread))
		filterContextAccount = ObjCBool(filter.context.contains(.account))

		if let expirationDate = filter.expiresAt {
			let remainingMinutes = expirationDate.timeIntervalSince(Date()) / 60
			let availableItems = expirationDatePopUpButton.itemArray.compactMap(\.identifier?.rawValue)
																	.compactMap(Int.init)

			for availableItem in availableItems {
				if Int(remainingMinutes) <= availableItem {
					selectExpirationDatePopUpButtonItem(identifier: "\(availableItem)")
					break
				}
			}
		} else {
			selectExpirationDatePopUpButtonItem(identifier: "never")
		}

		if filter.irreversible {
			selectActionPopUpButtonItem(identifier: "drop")
		} else {
			selectActionPopUpButtonItem(identifier: "hide")
		}
	}

	private func selectExpirationDatePopUpButtonItem(identifier: String) {
		if let item = expirationDatePopUpButton.itemArray.first(where: { $0.identifier?.rawValue == identifier }) {
			expirationDatePopUpButton.select(item)
		}
	}

	private func selectActionPopUpButtonItem(identifier: String) {
		if let item = actionPopUpButton.itemArray.first(where: { $0.identifier?.rawValue == identifier }) {
			actionPopUpButton.select(item)
		}
	}

	private func updateCanSave() {
		canSave = ObjCBool(filterPhrase.isEmpty == false)
	}

	private func resetBindings() {
		filterPhrase = ""
		filterWholeWord = false
		filterContextHome = false
		filterContextNotifications = false
		filterContextPublic = false
		filterContextThread = false
		filterContextAccount = false
	}

	@IBAction func cancel(_ sender: Any) {
		dismissBlock?()
	}

	@IBAction func save(_ sender: Any) {
		guard let saveBlock = saveBlock,
			  let actionIdentifier = actionPopUpButton.selectedItem?.identifier?.rawValue,
			  let expirationIdentifier = expirationDatePopUpButton.selectedItem?.identifier?.rawValue
		else {
			return
		}

		let irreversible = actionIdentifier == "drop"
		let expiration: Date?

		if expirationIdentifier == "never" {
			expiration = nil
		}
		else if expirationIdentifier == "custom" {
			expiration = expirationDatePicker.dateValue
		}
		else if let minutes = Double(expirationIdentifier), "\(minutes)" == expirationIdentifier {
			expiration = Date(timeIntervalSinceNow: minutes * 60)
		}
		else {
			// Fallback
			dismissBlock?()
			return
		}

		var filterContext: [Filter.Context] = []
		if filterContextHome.boolValue { filterContext.append(.home) }
		if filterContextNotifications.boolValue { filterContext.append(.notifications) }
		if filterContextPublic.boolValue { filterContext.append(.public) }
		if filterContextThread.boolValue { filterContext.append(.thread) }
		if filterContextAccount.boolValue { filterContext.append(.account) }

		saveBlock(UserFilter(id: "internal", phrase: filterPhrase, context: filterContext, expiresAt: expiration,
							 wholeWord: filterWholeWord.boolValue, irreversible: irreversible), mode)
	}

	@IBAction func didSelectExpirationValue(_ sender: Any) {
		let showDatePicker = expirationDatePopUpButton.selectedItem?.identifier?.rawValue == "custom"
		expirationDatePicker.isHidden = !showDatePicker
		expirationDateLabel.isHidden = !showDatePicker

		if showDatePicker {
			let now = Date()
			expirationDatePicker.dateValue = now
			expirationDateLabel.objectValue = now
		}
	}

	enum Mode {
		case create
		case edit(UserFilter)
	}
}
