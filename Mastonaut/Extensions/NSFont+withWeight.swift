//
//  NSFont+withWeight.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 30.04.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import AppKit
import Foundation

extension NSFont
{
	/// Rough mapping from behavior of `.systemFont(…weight:)`
	/// to `NSFontManager`'s `Int`-based weight,
	/// as of 13.4 Ventura
	func withWeight(weight: NSFont.Weight) -> NSFont?
	{
		let fontManager=NSFontManager.shared

		var intWeight: Int

		switch weight
		{
		case .ultraLight:
			intWeight=0
		case .light:
			intWeight=2 // treated as ultraLight
		case .thin:
			intWeight=3
		case .medium:
			intWeight=6
		case .semibold:
			intWeight=8 // treated as bold
		case .bold:
			intWeight=9
		case .heavy:
			intWeight=10 // treated as bold
		case .black:
			intWeight=15 // .systemFont does bold here; we do condensed black
		default:
			intWeight=5 // treated as regular
		}

		return fontManager.font(withFamily: self.familyName ?? "",
		                        traits: .unboldFontMask,
		                        weight: intWeight,
		                        size: self.pointSize)
	}
}
