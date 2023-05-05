//
//  CellMenuItemHandler.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 03.09.20.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2020 Bruno Philipe.
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

import Foundation
import CoreTootin

class CellMenuItemHandler {

	unowned let tableView: NSTableView
	unowned let interactionHandler: StatusInteractionHandling

	init(tableView: NSTableView, interactionHandler: StatusInteractionHandling) {
		self.tableView = tableView
		self.interactionHandler = interactionHandler
	}

	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {

		guard let selectedIndex = tableView.selectedRowIndexes.first,
			  let view = tableView.view(atColumn: 0, row: selectedIndex, makeIfNecessary: false),
			  let cellView = view as? StatusTableCellView,
			  let cellModel = cellView.cellModel
		else {
			return false
		}

		switch menuItem.action {
		case #selector(copy(_:)):
			return true
				
		case #selector(copyTootText(_:)):
			return true

		case #selector(favoriteSelectedStatus(_:)):
			menuItem.title = cellModel.isFavorited == true ? 🔠("status.action.favorite.undo")
														   : 🔠("status.action.favorite")

		case #selector(reblogSelectedStatus(_:)):
			menuItem.title = cellModel.isReblogged == true ? 🔠("status.action.reblog.undo")
														   : 🔠("status.action.reblog")

		case #selector(toggleMediaVisibilityOfSelectedStatus(_:)):
			menuItem.title = cellView.isMediaHidden ? 🔠("status.action.media")
													: 🔠("status.action.media.undo")

			return cellView.hasMedia

		case #selector(toggleContentVisibilityOfSelectedStatus(_:)):
			menuItem.title = cellView.isContentHidden ? 🔠("status.action.content")
													  : 🔠("status.action.content.undo")

			return cellView.hasSpoiler

		case #selector(togglePresentableMediaVisible(_:)) where tableView.window?.isKeyWindow == true:
			menuItem.title = 🔠("status.action.media.open")
			return cellView.hasMedia

		case #selector(replyToSelectedStatus(_:)),
			 #selector(showDetailsOfSelectedStatus(_:)):
			break

		default:
			return false
		}

		return true
	}

	private func selectedCellView() -> StatusTableCellView? {
		guard let selectedRow = tableView.selectedRowIndexes.first,
			  let cellView = tableView.view(atColumn: 0, row: selectedRow, makeIfNecessary: false)
		else { return nil }

		return cellView as? StatusTableCellView
	}

	private func selectedCellViewModel() -> StatusCellModel? {
		return selectedCellView()?.cellModel
	}
	
	@IBAction func copy(_ sender: Any?) {
		guard let status = selectedCellViewModel()?.status,
			  let menuItem = sender as? NSMenuItem
		else { return }
		
		let finalStatus = status.reblog ?? status

		let representedObject = finalStatus.url?.absoluteString ?? finalStatus.uri
		menuItem.representedObject = representedObject
		
		StatusMenuItemsController.shared.copyRepresentedObject(menuItem)
	}

	@IBAction func copyTootText(_ sender: Any?) {
		guard let status = selectedCellViewModel()?.status,
			  let menuItem = sender as? NSMenuItem
		else { return }
		
		let representedObject = (status.reblog?.attributedContent.string ?? status.attributedContent.string)
								as NSString
		menuItem.representedObject = representedObject
		
		StatusMenuItemsController.shared.copyRepresentedObject(menuItem)
	}

	@IBAction
	func favoriteSelectedStatus(_ sender: Any?) {
		guard let cellModel = selectedCellViewModel() else { return }

		if cellModel.isFavorited {
			cellModel.handle(interaction: .unfavorite)
		} else {
			cellModel.handle(interaction: .favorite)
		}
	}

	@IBAction
	func reblogSelectedStatus(_ sender: Any?) {
		guard let cellModel = selectedCellViewModel() else { return }

		if cellModel.isReblogged {
			cellModel.handle(interaction: .unreblog)
		} else {
			cellModel.handle(interaction: .reblog)
		}
	}

	@IBAction
	func replyToSelectedStatus(_ sender: Any?) {
		selectedCellViewModel()?.handle(interaction: .reply)
	}

	@IBAction
	func toggleMediaVisibilityOfSelectedStatus(_ sender: Any?) {
		selectedCellView()?.toggleMediaVisibility()
	}

	@IBAction
	func toggleContentVisibilityOfSelectedStatus(_ sender: Any?) {
		selectedCellView()?.toggleContentVisibility()
	}

	@IBAction
	func showDetailsOfSelectedStatus(_ sender: Any?) {
		guard let cellModel = selectedCellViewModel() else { return }
		interactionHandler.show(status: cellModel.status)
	}

	@IBAction
	func togglePresentableMediaVisible(_ sender: Any?) {
		guard let mediaPresenter = selectedCellView() else { return }
		mediaPresenter.makePresentableMediaVisible()
	}
}
