//
//  CocoapodAcknowledgment.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 03.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

struct CocoapodAcknowledgements: Codable
{
	var entries: [Entry]

	enum CodingKeys: String, CodingKey
	{
		case entries = "PreferenceSpecifiers"
	}

	struct Entry: Codable
	{
		let title: String
		let text: String

		enum CodingKeys: String, CodingKey
		{
			case title = "Title"
			case text = "FooterText"
		}
	}
}

extension CocoapodAcknowledgements
{
	static func load(plist: String) -> CocoapodAcknowledgements?
	{
		guard
			let cocoaPodsAcknowledgementsUrl = Bundle.main.url(forResource: plist, withExtension: "plist"),
			let cocoaPodsAcknowledgementsData: Data = try? Data(contentsOf: cocoaPodsAcknowledgementsUrl)
		else
		{
			return nil
		}
		
		let acknowledgements = try! PropertyListDecoder().decode(CocoapodAcknowledgements.self, from: cocoaPodsAcknowledgementsData)
		
		return acknowledgements
	}
}
