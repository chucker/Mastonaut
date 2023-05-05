//
//  FontService.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 01.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Cocoa
import CoreTootin

struct FontService {
	/// The base font, whose family and size is used. This is typically
	/// either the default, or a font picked from the preferences, where
	/// regular and focused statuses can be configured separately (for
	/// example, a focused status is by default larger).
	///
	/// Note that this type does not support relative font size changes.
	/// Previously, for example, `bio` was smaller than `status`. At
	/// some point in the future, we may want to address that.
	init(font: NSFont) {
		self.font = font
	}

	let font: NSFont

	public func authorAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.labelColor,
			.font: font.withWeight(weight: .semibold)!
		]
	}
	
	public func favoriteAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.statusFavorited,
			.font: font.withWeight(weight: .medium)!
		]
	}
	
	public func followAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.labelColor,
			.font: font.withWeight(weight: .medium)!
		]
	}
	
	public func interactionAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.labelColor,
			.font: font.withWeight(weight: .medium)!
		]
	}
	
	public func reblogAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.statusReblogged,
			.font: font.withWeight(weight: .medium)!
		]
	}
	
	public func statusAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.labelColor,
			.font: font,
			.underlineStyle: NSNumber(value: 0) // <-- This is a hack to prevent the label's contents from shifting
			// vertically when clicked.
		]
	}
	
	public func statusLinkAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.safeControlTintColor,
			.font: font.withWeight(weight: .medium)!,
			.underlineStyle: NSNumber(value: 1)
		]
	}
	
	public func userBioAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.labelColor,
			.font: font,
			.underlineStyle: NSNumber(value: 0) // <-- This is a hack to prevent the label's contents from shifting
											 // vertically when clicked.
		]
	}
	
	public func userBioLinkAttributes() -> [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: NSColor.labelColor,
			.font: font.withWeight(weight: .medium)!,
			.underlineStyle: NSNumber(value: 1)
		]
	}
}
