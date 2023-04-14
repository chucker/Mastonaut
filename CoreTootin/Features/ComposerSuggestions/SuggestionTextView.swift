//
//  SuggestionTextView.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 10.06.19.
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

open class SuggestionTextView: NSTextView
{
	public weak var accountSuggestionsProvider: SuggestionTextViewSuggestionsProvider?
	public weak var hashtagSuggestionsProvider: SuggestionTextViewSuggestionsProvider?

	public weak var imagesProvider: AccountSuggestionWindowImagesProvider?
	{
		get { return accountSuggestionWindowController.imagesProvider }
		set { accountSuggestionWindowController.imagesProvider = newValue }
	}

	public private(set) lazy var accountSuggestionWindowController = SuggestionWindowController(mode: .mention)
	public private(set) lazy var hashtagSuggestionWindowController = SuggestionWindowController(mode: .hashtag)

	public var activeSuggestionWindowController: SuggestionWindowController?

	private var lastSuggestionRequestId: UUID?

	override public func moveUp(_ sender: Any?)
	{
		guard let activeSuggestionWindowController, activeSuggestionWindowController.isWindowVisible
		else
		{
			super.moveUp(sender)
			return
		}

		activeSuggestionWindowController.selectPrevious(sender)
	}

	override public func moveDown(_ sender: Any?)
	{
		guard let activeSuggestionWindowController, activeSuggestionWindowController.isWindowVisible
		else
		{
			super.moveDown(sender)
			return
		}

		activeSuggestionWindowController.selectNext(sender)
	}

	override public func cancelOperation(_ sender: Any?)
	{
		guard let activeSuggestionWindowController, activeSuggestionWindowController.isWindowVisible
		else
		{
			return
		}

		dismissSuggestionsWindow()
	}

	open func textStorage(_ textStorage: NSTextStorage,
	                      didProcessEditing editedMask: NSTextStorageEditActions,
	                      range editedRange: NSRange,
	                      changeInLength delta: Int)
	{
		guard
			undoManager?.isUndoing != true,
			editedMask.contains(.editedCharacters)
		else { return }

		DispatchQueue.main.async
		{
			self.dispatchSuggestionsFetch()
		}
	}

	public func dispatchSuggestionsFetch()
	{
		SuggestionTextView.cancelPreviousPerformRequests(withTarget: self,
		                                                 selector: #selector(reallyDispatchSuggestionsFetch),
		                                                 object: nil)

		perform(#selector(reallyDispatchSuggestionsFetch), with: nil, afterDelay: 0.33)
	}

	public func dismissSuggestionsWindow()
	{
		activeSuggestionWindowController?.close()
	}

	public func insertCurrentlySelectedSuggestion()
	{
		activeSuggestionWindowController?.insertSelectedSuggestion()
		dismissSuggestionsWindow()
	}

	// MARK: Private Stuff

	@objc private func reallyDispatchSuggestionsFetch()
	{
		let selection = selectedRange()
		let string = self.string

		guard
			selection.length == 0,
			let (mode, mention, range) = string.mentionUpTo(index: selection.location)
		else
		{
			dismissSuggestionsWindow()
			return
		}

		let requestId = UUID()
		lastSuggestionRequestId = requestId

		if mode == .mention, let provider = accountSuggestionsProvider
		{
			provider.suggestionTextView(self, suggestionsForQuery: mention)
			{
				[weak self] result in

				guard let container = result as? [SuggestionContainer],
				      !container.isEmpty,
				      case SuggestionContainer.mention = container[0]
				else
				{
					DispatchQueue.main.async { self?.dismissSuggestionsWindow() }
					return
				}

				DispatchQueue.main.async
				{
					guard self?.lastSuggestionRequestId == requestId else { return }
					self?.showSuggestionsWindow(mode: mode, with: container, mentionRange: range)
				}
			}
		}
		else if mode == .hashtag, let provider = hashtagSuggestionsProvider
		{
			provider.suggestionTextView(self, suggestionsForQuery: mention)
			{
				[weak self] result in

				guard let container = result as? [SuggestionContainer],
				      !container.isEmpty,
				      case SuggestionContainer.hashtag = container[0]
				else
				{
					DispatchQueue.main.async { self?.dismissSuggestionsWindow() }
					return
				}

				DispatchQueue.main.async
				{
					guard self?.lastSuggestionRequestId == requestId else { return }
					self?.showSuggestionsWindow(mode: mode, with: container, mentionRange: range)
				}
			}
		}
		else
		{
			dismissSuggestionsWindow()
		}
	}

	private func showSuggestionsWindow(mode: SuggestionMode,
	                                   with suggestions: [SuggestionContainer], mentionRange: NSRange)
	{
		guard
			mentionRange.upperBound <= (textStorage?.length ?? 0),
			let window = window,
			let layoutManager = layoutManager,
			let textContainer = textContainer
		else
		{
			dismissSuggestionsWindow()
			return
		}

		let glyphRange = layoutManager.glyphRange(forCharacterRange: mentionRange, actualCharacterRange: nil)
		let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
		let offsetRect = convert(rect.offsetBy(dx: textContainerInset.width, dy: textContainerInset.height), to: nil)
		let screenRect = window.convertToScreen(offsetRect)

		switch mode
		{
		case .mention:
			activeSuggestionWindowController = accountSuggestionWindowController
		case .hashtag:
			activeSuggestionWindowController = hashtagSuggestionWindowController
		}

		guard let activeSuggestionWindowController else { return }

		activeSuggestionWindowController.set(suggestionContainers: suggestions)
		activeSuggestionWindowController.showWindow(nil)

		activeSuggestionWindowController.insertSuggestionBlock =
		{
			[weak self] suggestion in
			guard let self = self else { return }

			switch suggestion
			{
			case let .mention(account):
				self.replaceCharacters(in: mentionRange, with: "\(account.text) ")
			case let .hashtag(hashtag):
				self.replaceCharacters(in: mentionRange, with: "#\(hashtag.text) ")
			}

			// make sure
			self.delegate?.textDidChange?(Notification(name: NSControl.textDidChangeNotification, object: self))

			// (unsure why `NotificationCenter.default.post` doesn't work)
		}

		activeSuggestionWindowController.positionWindow(under: screenRect)
	}
}

@objc public protocol SuggestionTextViewSuggestionsProvider: AnyObject
{
	func suggestionTextView(_ textView: SuggestionTextView,
	                        suggestionsForQuery: String,
	                        completion: @escaping (Any) -> Void)
}

enum SuggestionMode
{
	case mention
	case hashtag
}

enum SuggestionContainer
{
	case mention(AccountSuggestionProtocol)
	case hashtag(HashtagSuggestionProtocol)
}

private extension NSString
{
	func mentionUpTo(index: Int) -> (mode: SuggestionMode, mention: String, range: NSRange)?
	{
		guard length > 0, index <= length else { return nil }

		var previousTokenCharacterIndex: Int?
		let charsetTokens = NSCharacterSet(charactersIn: "@#")

		func modeFromCharIndex(_ charIndex: Int) -> SuggestionMode?
		{
			switch character(at: charIndex)
			{
			case "@".utf16.first:
				return .mention
			case "#".utf16.first:
				return .hashtag
			default:
				return nil
			}
		}

		for charIndex in (0 ..< index).reversed()
		{
			let char = character(at: charIndex)

			if (CharacterSet.whitespacesAndNewlines as NSCharacterSet).characterIsMember(char)
			{
				if let tokenCharacterIndex = previousTokenCharacterIndex
				{
					let mentionRange = NSMakeRange(tokenCharacterIndex, index - tokenCharacterIndex)
					let mention = substring(with: mentionRange)
					return (modeFromCharIndex(tokenCharacterIndex)!, mention, mentionRange)
				}

				// Found an empty space character before an `@` or `#` character
				return nil
			}
			else if charsetTokens.characterIsMember(char), index - charIndex > 1
			{
				if previousTokenCharacterIndex != nil
				{
					let mentionRange = NSMakeRange(charIndex, index - charIndex)
					let mention = substring(with: mentionRange)
					return (modeFromCharIndex(charIndex)!, mention, mentionRange)
				}

				previousTokenCharacterIndex = charIndex
			}
		}

		if let tokenCharacterIndex = previousTokenCharacterIndex
		{
			let mentionRange = NSMakeRange(tokenCharacterIndex, index - tokenCharacterIndex)
			let mention = substring(with: mentionRange)
			return (modeFromCharIndex(tokenCharacterIndex)!, mention, mentionRange)
		}

		// We never found an `@` character...
		return nil
	}
}
