//
//  MockClient.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 09.01.19.
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

import MastodonKit

class MockClient: ClientType
{
	let baseURL: String
	let session: URLSession

	let observers = ClientObserverList()

	weak var delegate: ClientDelegate?
	public var accessToken: String?
	{
		didSet
		{
			realClient.accessToken = accessToken

			if let accessToken = accessToken {
				observers.allObservers.forEach({ $0.client(self, didUpdate: accessToken) })
			}
		}
	}

	private var realClient: Client

	private var responseMap: [Int: Data] = [:]

	var mockCalls = true

	required public init(baseURL: String, accessToken: String? = nil, session: URLSession = .shared, delegate: ClientDelegate?)
	{
		self.baseURL = baseURL
		self.session = session
		self.accessToken = accessToken
		self.delegate = delegate

		realClient = Client(baseURL: baseURL, accessToken: accessToken, session: session)
	}

	func set<Model>(response: Data, for request: Request<Model>) throws
	{
		responseMap[try JSONEncoder().encode(request).hashValue] = response
	}

	private let mastodonFormatter: DateFormatter =
		{
			let dateFormatter = DateFormatter()

			dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SZ"
			dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
			dateFormatter.locale = Locale(identifier: "en_US_POSIX")

			return dateFormatter
		}()

	@discardableResult
	func run<Model: Codable>(_ request: Request<Model>,
							 resumeImmediately: Bool,
							 completion: @escaping (Result<Response<Model>, Error>) -> Void) -> FutureTask?
	{
		if mockCalls, let hash = try? JSONEncoder().encode(request).hashValue, let response = responseMap[hash]
		{
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .formatted(mastodonFormatter)

			guard
				let model = try? decoder.decode(Model.self, from: response)
			else
			{
				completion(.failure(ClientError.invalidModel))
				return nil
			}
			
			completion(.success(.init(value: model, pagination: nil)))
			return nil
		}
		else
		{
			return realClient.run(request, resumeImmediately: resumeImmediately, completion: completion)
		}
	}
	
	@available(macOS 10.15, *)
	func run<Model>(_ request: MastodonKit.Request<Model>) async throws -> MastodonKit.Response<Model> where Model : Decodable, Model : Encodable {
		try await withCheckedThrowingContinuation { continuation in
			run(request) { result in
				continuation.resume(with: result)
			}
		}
	}
	
	func runAndAggregateAllPages<Model: Codable>(requestProvider: @escaping (Pagination) -> Request<[Model]>,
												 completion: @escaping (Result<Response<[Model]>, Error>) -> Void)
	{
		realClient.runAndAggregateAllPages(requestProvider: requestProvider, completion: completion)
	}

	// MARK: - Observer Maintenance

	public func addObserver(_ observer: ClientObserver) {
		observers.addObserver(observer)
	}

	public func removeObserver(_ observer: ClientObserver) {
		observers.removeObserver(observer)
	}
}
