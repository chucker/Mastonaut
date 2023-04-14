//
//  HashtagSearchService.swift
//  CoreTootin
//
//  Created by Sören Kuklau on 19.03.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation
import MastodonKit

public class HashtagSearchService {
	private let client: ClientType

	public init(client: ClientType) {
		self.client = client
	}

	public func search(query: String, completion: @escaping ([Tag]) -> Void) {
		let _query = query.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

		client.run(Search.search(query: _query, type: .hashtags, excludeUnreviewed: false)) { result in

			guard case .success(let response) = result else {
				completion([])
				return
			}

			completion(response.value.hashtags)
		}
	}
}

extension HashtagSearchService: SuggestionTextViewSuggestionsProvider {
	public func suggestionTextView(_ textView: SuggestionTextView,
	                               suggestionsForQuery query: String,
	                               completion: @escaping (Any) -> Void)
	{
		search(query: query) {
			hashtags in

			DispatchQueue.main.async {
				let result = hashtags.map { SuggestionContainer.hashtag(HashtagSuggestion(hashtag: $0)) }

				completion(result)
			}
		}
	}
}

@objc public protocol HashtagSuggestionProtocol {
	var text: String { get }

	var uses: [Int] { get }
}

private class HashtagSuggestion: HashtagSuggestionProtocol {
	var uses: [Int]

	let text: String

	init(hashtag: Tag) {
		text = hashtag.name

		if let history = hashtag.history {
			uses = history.sorted(by: { $0.day > $1.day }).map { $0.uses }
		}
		else {
			uses = [Int]()
		}
	}
}
