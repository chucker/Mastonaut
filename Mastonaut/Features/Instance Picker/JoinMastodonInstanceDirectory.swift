//
//  InstanceDirectory.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 05.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

struct JoinMastodonInstanceDirectory {
	static let joinMastodonEndpointURL = URL(string: "https://api.joinmastodon.org/")!

	static let serversEndpointURL = joinMastodonEndpointURL.appendingPathComponent("servers")
	static let categoriesEndpointURL = joinMastodonEndpointURL.appendingPathComponent("categories")
	static let languagesEndpointURL = joinMastodonEndpointURL.appendingPathComponent("languages")
	
	public static func languages(
		  session: URLSession
	){
		var session = URLSession.shared
		
//		session.
//	-> AnyPublisher<Mastodon.Response.Content<[Mastodon.Entity.Language]>, Error>  {
//		  let request = Mastodon.API.get(
//			  url: languagesEndpointURL,
//			  query: nil,
//			  authorization: nil
//		  )
//		  return session.dataTaskPublisher(for: request)
//			  .tryMap { data, response in
//				  let value = try Mastodon.API.decode(type: [Mastodon.Entity.Language].self, from: data, response: response)
//				  return Mastodon.Response.Content(value: value, response: response)
//			  }
//			  .eraseToAnyPublisher()
	  }
}
