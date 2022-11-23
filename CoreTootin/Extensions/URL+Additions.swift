//
//  URL+Additions.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 05.02.19.
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
import UniformTypeIdentifiers

public extension URL
{
	var fileUTT: UTType?
	{
		return (try? resourceValues(forKeys: [.contentTypeKey]).contentType)
	}

	var preferredMimeType: String?
	{
		return fileUTT?.preferredMIMEType
	}

	func fileConforms(toUTT: UTType) -> Bool
	{
		guard let fileUTT = self.fileUTT else
		{
			return false
		}

		return fileUTT.conforms(to: toUTT)
	}

	var mastodonHandleFromAccountURI: String
	{
		guard let instance = host else
		{
			// Fallback
			return absoluteStringByDroppingScheme
		}

		// Mastodon: instance.domain/@username
		if pathComponents.count == 2, pathComponents[1].hasPrefix("@")
		{
			return "\(pathComponents[1])@\(instance)"
		}

		// Pleroma: instance.domain/users/username
		if pathComponents.count == 3, pathComponents[1] == "users"
		{
			return "@\(pathComponents[2])@\(instance)"
		}

		// Plume: instance.domain/@/username
		if pathComponents.count == 3, pathComponents[1] == "@", !pathComponents[2].hasPrefix("@")
		{
			return "@\(pathComponents[2])@\(instance)"
		}

		// PeerTube: instance.domain/accounts/username
		if pathComponents.count == 3, pathComponents[1] == "accounts"
		{
			return "@\(pathComponents[2])@\(instance)"
		}

		// Write.as: instance.domain/username
		if pathComponents.count == 2
		{
			return "@\(pathComponents[1])@\(instance)"
		}

		// Fallback
		return absoluteStringByDroppingScheme
	}

	var absoluteStringByDroppingScheme: String
	{
		let absoluteString = self.absoluteString

		guard let scheme = scheme else
		{
			return absoluteString
		}

		return absoluteString.substring(afterPrefix: "\(scheme)://")
	}
}
