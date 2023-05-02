//
//  Keychain.swift
//  CoreTootin
//
//  Created by Bruno Philipe on 13.09.19.
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

public class Keychain
{
	static let appGroup = "\(BuildConfig.DEVELOPMENT_TEAM).\(BuildConfig.MASTONAUT_BUNDLE_ID_BASE)"

	public private(set) lazy var keychainController: KeychainController = {
		let controller = KeychainController(service: "\(Keychain.appGroup).keychain")
		controller.keychainGroupIdentifier = Keychain.appGroup
		return controller
	}()

	public init() {}
}
