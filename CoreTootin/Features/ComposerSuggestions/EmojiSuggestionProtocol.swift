//
//  Protocols.swift
//  CoreTootin
//
//  Created by Sören Kuklau on 09.07.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import AppKit
import Foundation

@objc public protocol EmojiSuggestionProtocol {
	var text: String { get }

	func fetchImage(completion: @escaping (NSImage?) -> Void)
	func getReplacement() -> String
}
