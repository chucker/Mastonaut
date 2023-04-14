//
//  AccountSearchService.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 10.06.19.
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
import MastodonKit

public class AccountSearchService
{
	private let client: ClientType
	private let instance: Instance

	public init(client: ClientType, activeInstance: Instance)
	{
		self.client = client
		instance = activeInstance
	}

	public func search(query: String, completion: @escaping ([Account]) -> Void)
	{
		client.run(Accounts.search(query: query))
		{ result in
			guard case .success(let response) = result
			else
			{
				completion([])
				return
			}

			completion(response.value)
		}
	}
}

extension AccountSearchService: SuggestionTextViewSuggestionsProvider
{
	public func suggestionTextView(_ textView: SuggestionTextView,
	                               suggestionsForQuery query: String,
	                               completion: @escaping (Any) -> Void)
	{
		let instance = self.instance

		search(query: query)
		{
			accounts in

			DispatchQueue.main.async
			{
				let result = accounts.map { SuggestionContainer.mention(AccountSuggestion(account: $0, instance: instance)) }

				completion(result)
			}
		}
	}
}

@objc public protocol AccountSuggestionProtocol
{
	var text: String { get }
	var imageUrl: URL? { get }
	var displayName: String { get }
}

private class AccountSuggestion: AccountSuggestionProtocol
{
	let text: String
	let imageUrl: URL?
	let displayName: String

	init(account: Account, instance: Instance)
	{
		text = account.uri(in: instance)
		imageUrl = account.avatarURL
		displayName = account.bestDisplayName
	}
}
