//
//  ResourcesFetcher.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 07.01.19.
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
import CoreTootin

class ResourcesFetcher
{
	private let urlSession: URLSession
	private var observations: [URLSessionDataTask: NSKeyValueObservation] = [:]

	init(urlSession: URLSession = URLSession(configuration: .default))
	{
		self.urlSession = urlSession
	}

	@discardableResult
	func fetchData(from url: URL,
				   acceptableStatuses: [Int] = [200],
				   progress: ((Double) -> Void)? = nil,
				   completion: @escaping (FetchResult<Data>) -> Void) -> URLSessionDataTask
	{
		let taskPromise = Promise<URLSessionDataTask>()

		let task = urlSession.dataTask(with: url)
		{
			[weak self] (data, response, error) in

			if let error = error
			{
				completion(.failure(error))
			}
			else if let httpResponse = response as? HTTPURLResponse, !acceptableStatuses.contains(httpResponse.statusCode)
			{
				completion(.failure(FetchError.badStatus(httpResponse.statusCode)))
			}
			else if let data = data
			{
				completion(.success(data))
			}
			else
			{
				completion(.emptyResponse)
			}

			if let task = taskPromise.value
			{
				self?.observations.removeValue(forKey: task)
			}
		}

		taskPromise.value = task

		if let progressBlock = progress
		{
			observations[task] = task.observe(\URLSessionDataTask.countOfBytesReceived)
			{
				(task, _) in
				progressBlock(Double(task.countOfBytesReceived) / Double(task.countOfBytesExpectedToReceive))
			}
		}

		task.resume()

		return task
	}

	@discardableResult
	func fetchImage(with url: URL,
					acceptableStatuses: [Int] = [200],
					progress progressBlock: ((Double) -> Void)? = nil,
					completion: @escaping (FetchResult<NSImage>) -> Void) -> URLSessionDataTask
	{
		return fetchData(from: url, acceptableStatuses: acceptableStatuses, progress: progressBlock)
		{
			result in

			guard case .success(let data) = result else
			{
				completion(result.cast(to: NSImage.self))
				return
			}

			guard let image = NSImage(data: data) else
			{
				completion(.failure(FetchError.badData(data)))
				return
			}

			completion(.success(image))
		}
	}

	func fetchImages(with urls: [URL], completion: @escaping ([URL: FetchResult<NSImage>]) -> Void)
	{
		let dispatchGroup = DispatchGroup()
		let completionQueue = DispatchQueue(label: "images-fetch-completion")
		var results = [URL: FetchResult<NSImage>]()

		for url in urls
		{
			dispatchGroup.enter()
			fetchImage(with: url)
				{
					result in

					completionQueue.async
						{
							results[url] = result
							dispatchGroup.leave()
						}
				}
		}

		dispatchGroup.notify(queue: .main)
			{
				completion(results)
			}
	}

	func fetchDataSynchronously(from url: URL, acceptableStatuses: [Int] = [200]) -> FetchResult<Data>
	{
		assert(!Thread.isMainThread)

		let dispatchGroup = DispatchGroup()
		var fetchResult: FetchResult<Data>!

		dispatchGroup.enter()
		fetchData(from: url, acceptableStatuses: acceptableStatuses, progress: nil) { (result) in
			fetchResult = result
			dispatchGroup.leave()
		}

		dispatchGroup.wait()

		return fetchResult
	}

	enum FetchResult<T>
	{
		case success(T)
		case failure(Error)
		case emptyResponse

		fileprivate func cast<K>(to: K.Type) -> FetchResult<K>
		{
			switch self
			{
			case .failure(let error):
				return .failure(error)

			default:
				return .emptyResponse
			}
		}
	}

	enum FetchError: Error
	{
		case badStatus(Int)
		case badData(Data)
	}
}

extension ResourcesFetcher: AccountSuggestionWindowImagesProvider
{
	func suggestionWindow(_ windowController: SuggestionWindowController,
						  imageForSuggestionUsingURL imageURL: URL,
						  completion: @escaping (NSImage?) -> Void)
	{
		fetchImage(with: imageURL)
			{
				(result) in

				guard case .success(let image) = result else
				{
					completion(nil)
					return
				}

				completion(image)
			}
	}
}
