//
//  Acknowledgements.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 08.02.19.
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

final class AcknowledgementsViewModel: ObservableObject
{
	@Published var entries: [Acknowledgement]
	@Published var selectedId: String?

	init()
	{
		entries = [Acknowledgement]()

		if let cocoapodAcknowledgements = CocoapodAcknowledgements.load(plist: "Pods-Mastonaut-acknowledgements")
		{
			for entry in cocoapodAcknowledgements.entries
			{
				entries.append(Acknowledgement(title: entry.title,
											   text: entry.text,
											   url: nil))
			}
		}

		for acknowledgement in AdditionalAcknowledgements.entries
		{
			entries.append(acknowledgement)
		}

		for acknowledgement in SwiftPMAcknowledgements.entries
		{
			entries.append(acknowledgement)
		}

		entries = entries
			.filter { !$0.title.isEmpty }
			.filter { $0.title != "Acknowledgements" } // automatic entry from Cocoapods
			.sorted(by: { $0.title < $1.title })
	}
}

struct Acknowledgement: Identifiable
{
	let id = UUID().uuidString
	let title: String
	let text: String?
	
	let url: String?
}
