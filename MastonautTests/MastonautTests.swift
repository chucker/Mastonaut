//
//  MastonautTests.swift
//  MastonautTests
//
//  Created by Bruno Philipe on 21.03.19.
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

import CoreTootin
import MastodonKit
@testable import Mastonaut
import XCTest

class MastonautTests: XCTestCase {
	override func setUp() {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testAllRangesString() {
		let string = "banana" as NSString

		XCTAssertEqual(string.allRanges(of: "ba"), [NSMakeRange(0, 2)])
		XCTAssertEqual(string.allRanges(of: "na"), [NSMakeRange(2, 2), NSMakeRange(4, 2)])
		XCTAssertEqual(string.allRanges(of: "ca"), [])
	}

	func testStrippingEmojiAttachments() {
		let emojiURL = URL(string: "https://aaaa.com")!
		let emoji = Emoji(shortcode: "emoji", staticURL: emojiURL, url: emojiURL, visibleInPicker: true)
		let shortcodeString = "This string has an :emoji:!" as NSMutableString
		let attributedString = shortcodeString.applyingEmojiAttachments([CacheableEmoji(emoji, instance: "")])
		let strippedString = attributedString.strippingEmojiAttachments(insertJoinersBetweenEmojis: true)

		XCTAssertEqual(shortcodeString as String, strippedString)
	}

	func testStrippingMultipleEmojiAttachments() {
		let emojiURL = URL(string: "https://aaaa.com")!
		let emoji1 = Emoji(shortcode: "emoji", staticURL: emojiURL, url: emojiURL, visibleInPicker: true)
		let emoji2 = Emoji(shortcode: "another_emoji", staticURL: emojiURL, url: emojiURL, visibleInPicker: true)
		let shortcodeString = "This string has an :emoji: and :another_emoji:!" as NSMutableString
		let attributedString = shortcodeString.applyingEmojiAttachments([
			CacheableEmoji(emoji1, instance: ""), CacheableEmoji(emoji2, instance: "")
		])
		let strippedString = attributedString.strippingEmojiAttachments(insertJoinersBetweenEmojis: true)

		XCTAssertEqual(shortcodeString as String, strippedString)
	}

	func testStrippingMultipleEmojiAttachmentsInSequence() {
		let emojiURL = URL(string: "https://aaaa.com")!
		let emoji1 = Emoji(shortcode: "emoji", staticURL: emojiURL, url: emojiURL, visibleInPicker: true)
		let emoji2 = Emoji(shortcode: "another_emoji", staticURL: emojiURL, url: emojiURL, visibleInPicker: true)
		let shortcodeString = "This string has :emoji::another_emoji:!" as NSMutableString
		let attributedString = shortcodeString.applyingEmojiAttachments([
			CacheableEmoji(emoji1, instance: ""), CacheableEmoji(emoji2, instance: "")
		])
		let strippedString = attributedString.strippingEmojiAttachments(insertJoinersBetweenEmojis: false)

		XCTAssertEqual(shortcodeString as String, strippedString)
	}

	func testStrippingMultipleEmojiAttachmentsInSequenceWithZWJ() {
		let emojiURL = URL(string: "https://aaaa.com")!
		let emoji1 = Emoji(shortcode: "emoji", staticURL: emojiURL, url: emojiURL, visibleInPicker: true)
		let emoji2 = Emoji(shortcode: "another_emoji", staticURL: emojiURL, url: emojiURL, visibleInPicker: true)
		let shortcodeString = "This string has :emoji::another_emoji:!" as NSMutableString
		let attributedString = shortcodeString.applyingEmojiAttachments([
			CacheableEmoji(emoji1, instance: ""), CacheableEmoji(emoji2, instance: "")
		])

		let strippedString = attributedString.strippingEmojiAttachments(insertJoinersBetweenEmojis: true)

		XCTAssertEqual(strippedString, "This string has :emoji:\u{200D}:another_emoji:!")
	}
}
