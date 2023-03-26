//
//  RedrawsOnSelectTableRowView.swift
//  CoreTootin
//
//  Created by Sören Kuklau on 22.03.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import AppKit
import Foundation

public class RedrawsOnSelectTableRowView: NSTableRowView {
	override public var isSelected: Bool {
		willSet(newValue) {
			super.isSelected = newValue

			if subviews.count >= 2, let tableView, tableView.numberOfRows > 0 {
				let column = tableView.tableColumns[tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("history"))]

				for row in 0 ..< tableView.numberOfRows {
					let rowView = tableView.rowView(atRow: row, makeIfNecessary: false)

					for cell in 0 ..< tableView.numberOfColumns {
						if let rowView, let cellView = tableView.view(atColumn: cell, row: row, makeIfNecessary: false) as? SparklineTableCellView {
							cellView.redraw(isSelected: rowView.isSelected)
						}
					}
				}
			}
		}
	}

	public var tableView: NSTableView?
}
