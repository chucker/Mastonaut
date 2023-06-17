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

	override func draw(_ rect: CGRect) {
		let path = NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
		let color = NSColor.systemBlue
		color.set()
//		path.stroke()
		path.fill()
	}
}
