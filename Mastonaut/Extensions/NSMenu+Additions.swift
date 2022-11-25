//
//  NSMenu+Additions.swift
//  Mastonaut
//
//  Created by Bruno on 29.01.19.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2019 Bruno Philipe.
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

extension NSMenuItem
{
	var columnModel: ColumnMode?
	{
		return representedObject as? ColumnMode
	}

	convenience init(title: String, submenu: NSMenu)
	{
		self.init(title: title, action: nil, keyEquivalent: "")
		self.submenu = submenu
	}

	convenience init(_ title: String?, object: Any? = nil)
	{
		self.init(title: title ?? "", action: nil, keyEquivalent: "")
		representedObject = object
	}

	func with(modifierMask: NSEvent.ModifierFlags) -> Self
	{
		keyEquivalentModifierMask = modifierMask
		return self
	}
	
	/// Mimics the style in menus such as Services. Those are actually implemented
	/// as a view, which enables making them left-aligned. Alas, that view is a private
	/// API.
	///
	/// Make sure to set `autoenablesItems = false` on the parent menu.
	static func sectionHeader(_ title: String) -> NSMenuItem
	{
		let smallBoldSystemFont = NSFont.systemFont(ofSize: 11, weight: NSFont.Weight.semibold)
		
		let item = NSMenuItem()
		let attributedTitle = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font: smallBoldSystemFont])
		item.attributedTitle = attributedTitle
		item.isEnabled = false
		
		return item
	}
}
