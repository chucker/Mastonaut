//
//  AboutWindowController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 04.02.19.
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

class AboutWindowController: NSWindowController
{
	@IBOutlet weak var versionLabel: NSTextField!
	@IBOutlet weak var copyrightLabel: NSTextField!

	private lazy var acknowledgementsWindow = AcknowledgementsWindow()

	override func windowDidLoad()
	{
		super.windowDidLoad()

		// Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
		if
			let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
			let bundleBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
		{
			versionLabel.stringValue = 🔠("Version: %@ (%@)", bundleVersion, bundleBuild)
		}

		if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
		{
			copyrightLabel.stringValue = 🔠(copyright)
		}
	}

	override var windowNibName: NSNib.Name?
	{
		return "AboutWindowController"
	}

	@IBAction func openHomepage(_ sender: Any?)
	{
		NSWorkspace.shared.open(URL(string: "https://mastonaut.app")!)
	}

	@IBAction func openPrivacyPolicy(_ sender: Any?)
	{
		NSWorkspace.shared.open(URL(string: "https://mastonaut.app/privacy")!)
	}

	@IBAction func orderFrontAcknowledgementsWindow(_ sender: Any?)
	{
		acknowledgementsWindow.makeKeyAndOrderFront(sender)
		acknowledgementsWindow.center()
	}
}
