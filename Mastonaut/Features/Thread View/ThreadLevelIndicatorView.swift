//
//  ThreadLevelIndicator.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 14.06.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

class ThreadLevelIndicatorView : NSView {
	override func draw(_ rect: CGRect) {
		let path = NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
		let color = NSColor.systemBlue
		color.set()
//		path.stroke()
		path.fill()
	}
}
