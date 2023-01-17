//
//  MastonautPreferences.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 05.01.19.
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

public let Preferences = MastonautPreferences.instance

public class MastonautPreferences: PreferencesController
{
	private static var sharedInstance: MastonautPreferences! = nil

	override var suiteName: String?
	{
		return "\(BuildConfig.DEVELOPMENT_TEAM).\(BuildConfig.MASTONAUT_BUNDLE_ID_BASE)"
	}

	/// Initializer declared as private to avoid accidental creation of new instances.
	private override init()
	{
		super.init()

		defaults.removeObject(forKey: #keyPath(currentUser))
	}

	/// The shared instance of the Preferences class.
	@objc public class var instance: MastonautPreferences
	{
		if sharedInstance == nil
		{
			sharedInstance = MastonautPreferences()
		}
		
		return sharedInstance
	}

	@objc private dynamic var currentUser: UUID?
	{
		get { return uuid(forKey: #keyPath(currentUser)) }
		set { defaults.setValue(newValue?.uuidString, forKey: #keyPath(currentUser)) }
	}

	// General preferences

	@objc public dynamic var timelinesResizeMode: TimelinesResizeMode
	{
		get { return integerRepresentable(for: #keyPath(timelinesResizeMode), default: .expandWindowFirst) }
		set { defaults.setValue(newValue.rawValue, forKey: #keyPath(timelinesResizeMode)) }
	}

	@objc public dynamic var newWindowAccountMode: NewWindowAccountMode
	{
		get { return integerRepresentable(for: #keyPath(newWindowAccountMode), default: .ask) }
		set { defaults.setValue(newValue.rawValue, forKey: #keyPath(newWindowAccountMode)) }
	}

	@objc public dynamic var didMigrateToSharedLocalKeychain: Bool
	{
		get { return bool(forKey: #keyPath(didMigrateToSharedLocalKeychain)) ?? false }
		set { defaults.setValue(newValue, forKey: #keyPath(didMigrateToSharedLocalKeychain)) }
	}
	
	@objc public dynamic var appearance: Appearance
	{
		get { return integerRepresentable(for: #keyPath(appearance), default: .auto) }
		set { defaults.setValue(newValue.rawValue, forKey: #keyPath(appearance)) }
	}

	// Viewing preferences

	@objc public dynamic var mediaDisplayMode: MediaDisplayMode
	{
		get { return integerRepresentable(for: #keyPath(mediaDisplayMode), default: .hideSensitiveMedia) }
		set { defaults.setValue(newValue.rawValue, forKey: #keyPath(mediaDisplayMode)) }
	}

	@objc public dynamic var spoilerDisplayMode: SpoilerDisplayMode
	{
		get { return integerRepresentable(for: #keyPath(spoilerDisplayMode), default: .alwaysHide) }
		set { defaults.setValue(newValue.rawValue, forKey: #keyPath(spoilerDisplayMode)) }
	}

	@objc public dynamic var autoplayVideos: Bool
	{
		get { return bool(forKey: #keyPath(autoplayVideos)) ?? true }
		set { defaults.setValue(newValue, forKey: #keyPath(autoplayVideos)) }
	}

	// Composing preferences

	@objc public dynamic var defaultStatusAudience: StatusAudience
	{
		get { return integerRepresentable(for: #keyPath(defaultStatusAudience), default: .public) }
		set { defaults.setValue(newValue.rawValue, forKey: #keyPath(defaultStatusAudience)) }
	}

	@objc public dynamic var defaultReplyAudience: StatusAudience
	{
		get { return integerRepresentable(for: #keyPath(defaultReplyAudience), default: .unlisted) }
		set { defaults.setValue(newValue.rawValue, forKey: #keyPath(defaultReplyAudience)) }
	}

	@objc public dynamic var markMediaAsSensitive: Bool
	{
		get { return bool(forKey: #keyPath(markMediaAsSensitive)) ?? false }
		set { defaults.setValue(newValue, forKey: #keyPath(markMediaAsSensitive)) }
	}

	@objc public dynamic var insertDoubleNewLines: Bool
	{
		get { return bool(forKey: #keyPath(insertDoubleNewLines)) ?? true }
		set { defaults.setValue(newValue, forKey: #keyPath(insertDoubleNewLines)) }
	}

	@objc public dynamic var insertJoinersBetweenEmojis: Bool
	{
		get { return bool(forKey: #keyPath(insertJoinersBetweenEmojis)) ?? true }
		set { defaults.setValue(newValue, forKey: #keyPath(insertJoinersBetweenEmojis)) }
	}

	// Storages

	public func storedFrame(forTimelineWindowIndex index: Int) -> NSRect?
	{
		guard let frames: [String: String] = object(forKey: "MastonautPreferences.preservedWindowFrames") else
		{
			return nil
		}

		return frames["\(index)"].map { NSRectFromString($0) }
	}

	public func set(frame: NSRect, forTimelineWindowIndex index: Int)
	{
		var frames: [String: String] = object(forKey: "MastonautPreferences.preservedWindowFrames") ?? [:]
		frames["\(index)"] = NSStringFromRect(frame)
		defaults.setValue(frames, forKey: "MastonautPreferences.preservedWindowFrames")
	}
	
	// KVO
	
	public func addObserver(_ observer: NSObject, forKeyPath keyPath: String) {
		defaults.addObserver(observer, forKeyPath: keyPath, context: nil)
	}
}

public extension MastonautPreferences
{
	@objc enum Appearance : Int {
	    case auto = 1
	    case light
	    case dark
    }
	
	@objc enum MediaDisplayMode: Int
	{
		case alwaysHide = 1
		case hideSensitiveMedia
		case alwaysReveal
	}

	@objc enum SpoilerDisplayMode: Int
	{
		case alwaysHide = 1
		case hideMedia
		case alwaysReveal
	}

	@objc enum NewWindowAccountMode: Int
	{
		case ask = 1
		case pickFirstOne
	}

	@objc enum StatusAudience: Int, CaseIterable, MenuItemRepresentable
	{
		case `public` = 1
		case unlisted
		case `private`

		public static var allValues: [MastonautPreferences.StatusAudience] = [.public, .unlisted, .private]

		public var localizedTitle: String
		{
			switch self
			{
			case .public:	return 🔠("Public")
			case .unlisted:	return 🔠("Unlisted")
			case .private:	return 🔠("Private")
			}
		}

		public var icon: NSImage?
		{
			switch self
			{
			case .public:	return NSImage(named: "globe")
			case .unlisted:	return NSImage(named: "padlock_open")
			case .private:	return NSImage(named: "padlock")
			}
		}
	}

	@objc enum TimelinesResizeMode: Int
	{
		case expandWindowFirst = 1
		case shrinkColumnsFirst
	}
}
