//
//  BaseComposerTextView.swift
//  CoreTootin
//
//  Created by Bruno Philipe on 15.09.19.
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

import AppKit

@IBDesignable
open class BaseComposerTextView: SuggestionTextView
{
	@IBInspectable
	public var insertDoubleNewLines: Bool = false

	@IBOutlet
	public var submitControl: NSControl? = nil

	@IBOutlet
	public weak var pasteDelegate: BaseComposerTextViewPasteDelegate? = nil

	override public func insertNewline(_ sender: Any?)
	{
		if activeSuggestionWindowController?.isWindowVisible == true
		{
			insertCurrentlySelectedSuggestion()
			return
		}

		if insertDoubleNewLines
		{
			super.insertNewline(sender)
			super.insertNewline(sender)
		}
		else
		{
			super.insertNewline(sender)
		}
	}

	public func insertAttributedString(_ attributedString: NSAttributedString)
	{
		guard let textStorage = textStorage else { return }

		let selectedRange = self.selectedRange()

		if let undoManager = undoManager
		{
			let undoRange = NSMakeRange(selectedRange.location, attributedString.length)
			let undoString = textStorage.attributedSubstring(from: selectedRange)
			undoManager.registerUndo(withTarget: textStorage)
			{
				textStorage in textStorage.replaceCharacters(in: undoRange, with: undoString)
			}
		}

		textStorage.replaceCharacters(in: selectedRange, with: applyTypingAttributes(to: attributedString))
		didChangeText()
	}

	public func applyTypingAttributes(to string: NSAttributedString) -> NSAttributedString
	{
		let formattedString = string.mutableCopy() as! NSMutableAttributedString
		formattedString.addAttributes(typingAttributes, range: NSMakeRange(0, string.length))
		return formattedString
	}
}

@objc public protocol BaseComposerTextViewPasteDelegate: AnyObject
{
	/// Returns which pasteboard types the delegate is capable of reading from the pasteboard into the control.
	func readablePasteboardTypes(for controlTextView: BaseComposerTextView,
	                             proposedTypes: [NSPasteboard.PasteboardType]) -> [NSPasteboard.PasteboardType]

	/// Read the contents from the pasteboard into the control.
	///
	/// Asks the delegate to read from the pasteboard and modify the control's contents as appropriate. If the delegate
	/// reads any content from the pasteboard, it should return true. Returning false will result in the default paste
	/// behavior being applied.
	func readFromPasteboard(for controlTextView: BaseComposerTextView) -> Bool
}
