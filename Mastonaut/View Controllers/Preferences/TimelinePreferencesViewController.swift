//
//  TimelinePreferencesViewController.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 14.04.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation
import CoreTootin

class TimelinePreferencesViewController: NSViewController {
	@IBOutlet var preferencesView: NSView!
	
	override func awakeFromNib()
	{
		super.awakeFromNib()

		let preferences = MastonautPreferences.instance
		let view = StatusPrivacyPreferencesView(preferences: preferences)
	}
}
