//
//  SparklineTableCellView.swift
//  CoreTootin
//
//  Created by Sören Kuklau on 26.03.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import AppKit
import DSFSparkline
import Foundation

public class SparklineTableCellView: NSTableCellView {
	public var dataSource: DSFSparkline.DataSource?
	public var maxUses: Int?

	public func redraw(isSelected: Bool) {
		guard let dataSource else { return }

		let bitmap = DSFSparklineSurface.Bitmap()
		let stack = DSFSparklineOverlay.Bar()
		stack.dataSource = dataSource

		if !isSelected && effectiveAppearance != NSAppearance(named: .darkAqua) {
			stack.primaryStrokeColor = NSColor.textColor.cgColor
		}
		else {
			stack.primaryStrokeColor = NSColor.alternateSelectedControlTextColor.cgColor
		}

		bitmap.addOverlay(stack)

		if let attributedString = bitmap.attributedString(size: CGSize(width: 40, height: 18), scale: 2)
		{
			self.textField?.attributedStringValue = attributedString
		}
	}
}
