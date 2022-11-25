//
//  ListService.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 30.10.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import Foundation
import MastodonKit
import CoreTootin

struct FollowedListsService
{
	let client: ClientType
	let authorizedAccount: AuthorizedAccount
	
	func loadFollowedLists(completion: @escaping (Swift.Result<[List], Errors>) -> Void)
	{
		let request = Lists.all()
		
		client.run(request, completion:
		{
			result in

			switch result
			{
			case .success(let accounts, _):
				completion(.success(accounts))

			case .failure(let error):
				completion(.failure(.networkError(error)))
			}
		})
	}
	
	enum Errors: Error, UserDescriptionError
	{
		case networkError(Error)
		case persistenceError(Error)

		var userDescription: String
		{
			switch self
			{
			case .networkError(let error): return error.localizedDescription
			case .persistenceError(let error): return error.localizedDescription
			}
		}
	}
}
