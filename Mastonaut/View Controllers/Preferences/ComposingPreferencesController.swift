//
//  ComposingPreferencesController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 16.02.19.
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
import CoreTootin
import SwiftUI

class ComposingPreferencesController: NSViewController
{
	@IBOutlet var statusPrivacyPreferences: NSView!
	@IBOutlet private var defaultMarkAsSensitiveButton: NSButton!
	@IBOutlet private var insertDoubleNewLinesButton: NSButton!
	@IBOutlet private var insertZWJCharactersButton: NSButton!

	private var preferenceObservers: [AnyObject] = []

	override func awakeFromNib()
	{
		super.awakeFromNib()

		let preferences = MastonautPreferences.instance
		let view = StatusPrivacyPreferencesView(preferences: preferences)
		AppKitSwiftUIIntegration.hostSwiftUIView(view, inView: statusPrivacyPreferences)

		preferenceObservers.append(PreferenceCheckboxObserver(preference: \MastonautPreferences.markMediaAsSensitive,
		                                                      checkbox: defaultMarkAsSensitiveButton))

		preferenceObservers.append(PreferenceCheckboxObserver(preference: \MastonautPreferences.insertDoubleNewLines,
		                                                      checkbox: insertDoubleNewLinesButton))

		preferenceObservers.append(PreferenceCheckboxObserver(preference: \MastonautPreferences.insertJoinersBetweenEmojis,
		                                                      checkbox: insertZWJCharactersButton))
	}
}
