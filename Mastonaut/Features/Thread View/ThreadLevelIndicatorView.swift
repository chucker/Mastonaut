//
//  ThreadLevelIndicator.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 14.06.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

class ThreadLevelIndicatorView: NSView {
	public static let indicatorWidth  = 6
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
	}

	convenience init(threadContextItem: StatusThreadItem,
	                 height: CGFloat)
	{
		let frame = NSRect(x: threadContextItem.level * Self.indicatorWidth,
		                   y: 0,
						   width: Self.indicatorWidth,
		                   height: Int(height))

		self.init(frame: frame)

		self.threadContextItem = threadContextItem
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	var threadContextItem: StatusThreadItem!

	// inspired by Apollo, but more focused on having sufficient 'distance' between each level
	static let palette = [NSColor.systemOrange,
	                      NSColor.systemBlue,
	                      NSColor.systemPurple,
	                      NSColor.systemYellow,
	                      NSColor.systemMint,
	                      NSColor.systemRed,
	                      NSColor.systemTeal,
	                      NSColor.systemCyan,
	                      NSColor.systemPink,
	                      NSColor.systemGreen]

	override func draw(_ rect: CGRect) {
		let path = NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
		let color = Self.palette[threadContextItem.level % Self.palette.count - 1]
		color.set()
		path.fill()
	}
}
