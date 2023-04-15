//
//  ComposerTextView.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 09.02.19.
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

import Foundation
import CoreTootin

@IBDesignable
class ComposerTextView: BaseComposerTextView, NSTextStorageDelegate
{
	@IBInspectable
	var allowInsertingTabs: Bool = true

	@IBOutlet weak var emojiProvider: ComposerTextViewEmojiProvider? = nil

	override init(frame frameRect: NSRect)
	{
		super.init(frame: frameRect)
		setUp()
	}

	override init(frame frameRect: NSRect, textContainer container: NSTextContainer?)
	{
		super.init(frame: frameRect, textContainer: container)
		setUp()
	}

	required init?(coder: NSCoder)
	{
		super.init(coder: coder)
		setUp()
	}

	private func setUp()
	{
		textStorage?.delegate = self
	}

	override func insertTab(_ sender: Any?)
	{
		guard let activeSuggestionWindowController, activeSuggestionWindowController.isWindowVisible == false else
		{
			insertCurrentlySelectedSuggestion()
			return
		}

		if allowInsertingTabs
		{
			super.insertTab(sender)
		}
		else
		{
			window?.selectNextKeyView(sender)
		}
	}

	override func insertBacktab(_ sender: Any?)
	{
		window?.selectPreviousKeyView(sender)
	}

	override func updateDragTypeRegistration()
	{
		unregisterDraggedTypes()
		registerForDraggedTypes([.string])
	}

	override var readablePasteboardTypes: [NSPasteboard.PasteboardType]
	{
		guard let pasteDelegate = self.pasteDelegate else
		{
			return super.readablePasteboardTypes
		}

		return pasteDelegate.readablePasteboardTypes(for: self, proposedTypes: super.readablePasteboardTypes)
	}

	override func paste(_ sender: Any?)
	{
		if pasteDelegate?.readFromPasteboard(for: self) != true
		{
			super.paste(sender)
		}
	}

	override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool
	{
		guard let textStorage = self.textStorage else { return false }

		let aggregateString = NSMutableAttributedString()

		for range in selectedRanges.map({ $0.rangeValue })
		{
			if !aggregateString.isEmpty
			{
				aggregateString.append(NSAttributedString(string: "\n"))
			}

			aggregateString.append(textStorage.attributedSubstring(from: range))
		}

		let strippedString = aggregateString.strippingEmojiAttachments(insertJoinersBetweenEmojis: Preferences.insertJoinersBetweenEmojis)
		pboard.clearContents()
		pboard.writeObjects([strippedString as NSString])
		return true
	}

	func submit(_ sender: Any?)
	{
		if let submitControl = self.submitControl
		{
			submitControl.performClick(sender)
		}
	}

	override func interpretKeyEvents(_ eventArray: [NSEvent])
	{
		var skippedEvents = [NSEvent]()

		for event in eventArray
		{
			if event.specialKey == .carriageReturn, event.modifierFlags.contains(.command)
			{
				self.submit(event)
			}
			else
			{
				skippedEvents.append(event)
			}
		}

		super.interpretKeyEvents(skippedEvents)
	}

	override func textStorage(_ textStorage: NSTextStorage,
							  didProcessEditing editedMask: NSTextStorageEditActions,
							  range editedRange: NSRange,
							  changeInLength delta: Int)
	{
		super.textStorage(textStorage, didProcessEditing: editedMask, range: editedRange, changeInLength: delta)

		installEmojiSubviews(using: textStorage)

		guard
			undoManager?.isUndoing != true,
			editedMask.contains(.editedCharacters),
			editedRange.length > 0
		else { return }

		DispatchQueue.main.async
			{
				self.replaceShortcodesWithEmojiIfPossible()
			}
	}

	func replaceShortcodesWithEmojiIfPossible()
	{
		assert(Thread.isMainThread)

		guard
			let emojiProvider = self.emojiProvider,
			let textStorage = self.textStorage
		else { return }

		let currentSelection = selectedRange()
		let matches = NSRegularExpression.shortcodeRegex.matches(in: textStorage.string,
																 options: [],
																 range: NSMakeRange(0, textStorage.length))

		var rangeOffset = 0
		var didReplaceStrings = false
		for match in matches
		{
			let shortcodeRange = NSMakeRange(match.range(at: 1).location + rangeOffset, match.range(at: 1).length)
			let shortcode = textStorage.attributedSubstring(from: shortcodeRange).string

			guard match.range.intersection(currentSelection) == nil else
			{
				// Don't replace emoji if the editor caret is in that range
				continue
			}

			guard let emojiString = emojiProvider.composerTextView(self, emojiForShortcode: shortcode) else
			{
				continue
			}

			let replacementRange = NSMakeRange(match.range.location + rangeOffset, match.range.length)
			let replacementString = applyTypingAttributes(to: emojiString)

			if let undoManager = self.undoManager
			{
				let undoRange = NSMakeRange(replacementRange.location, emojiString.length)
				let undoString = textStorage.attributedSubstring(from: replacementRange)
				undoManager.registerUndo(withTarget: textStorage)
					{
						(textStorage) in textStorage.replaceCharacters(in: undoRange, with: undoString)
					}
			}

			textStorage.replaceCharacters(in: replacementRange, with: replacementString)
			rangeOffset += replacementString.length - match.range.length
			didReplaceStrings = true
		}

		if didReplaceStrings
		{
			didChangeText()
		}
	}
}

@objc protocol ComposerTextViewEmojiProvider: AnyObject
{
	func composerTextView(_ textView: ComposerTextView, emojiForShortcode: String) -> NSAttributedString?
}
