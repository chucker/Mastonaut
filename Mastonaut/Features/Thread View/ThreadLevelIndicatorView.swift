//
//  ThreadLevelIndicator.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 14.06.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

class ThreadLevelIndicatorView: NSView {
	public static let secondaryIndicatorWidth = 2
	public static let indicatorWidth = 6
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
	}

	convenience init(threadContextItem: StatusThreadItem,
	                 currentLevel: Int,
	                 height: CGFloat)
	{
		let frame = NSRect(x: currentLevel * Self.indicatorWidth,
		                   y: 0,
		                   width: Self.indicatorWidth,
		                   height: Int(height))

		self.init(frame: frame)

		self.threadContextItem = threadContextItem

		self.currentLevel = currentLevel

		self.isSecondary = currentLevel < threadContextItem.level

		if !isSecondary {
			if threadContextItem.level == 1 {
				self.toolTip = "This is a direct response to the focused post"
			}
			else {
				self.toolTip = "This is a response \(threadContextItem.level) levels underneath the focused post"
			}
		}
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	var threadContextItem: StatusThreadItem!

	var currentLevel: Int!

	var isSecondary: Bool!

	// inspired by Apollo, but more focused on having sufficient 'distance' between each level
	static let palette: [NSColor] = [.systemOrange,
	                                 .systemBlue,
	                                 .systemPurple,
	                                 .systemYellow,
	                                 .systemMint,
	                                 .systemRed,
	                                 .systemTeal,
	                                 .systemCyan,
	                                 .systemPink,
	                                 .systemGreen]

	override func draw(_ rect: CGRect) {
		let width = CGFloat(!isSecondary ? Self.indicatorWidth : Self.secondaryIndicatorWidth) / 2

		let path = NSBezierPath()
		path.move(to: NSPoint(x: rect.minX, y: rect.minY))
		path.line(to: NSPoint(x: rect.minX, y: rect.minY + rect.height))

		if isSecondary {
			path.setLineDash([1], count: 1, phase: 0)
		}

		path.lineWidth = width

		let color = Self.palette[currentLevel % Self.palette.count - 1]
		color.set()
		path.stroke()
	}
}
