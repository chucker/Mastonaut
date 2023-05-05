//
//  SearchViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 30.06.19.
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

import Cocoa
import MastodonKit
import CoreTootin

class SearchViewController: NSViewController
{
	@objc dynamic var searchTerm: String = ""

	@objc dynamic var hasTask: Bool
	{
		return searchTask != nil
	}

	@objc dynamic var hasSelection: Bool
	{
		return userSelection != nil
	}

	private var observations: [NSKeyValueObservation] = []
	private var searchTask: FutureTask?
	{
		willSet { willChangeValue(for: \.hasTask) }
		didSet { didChangeValue(for: \.hasTask) }
	}

	private var userSelection: SearchResultSelection? = nil
	{
		willSet { willChangeValue(for: \.hasSelection) }
		didSet { didChangeValue(for: \.hasSelection) }
	}

	private weak var resultsTabView: NSTabView? = nil

	var client: ClientType?
	var instance: Instance?
	weak var searchDelegate: SearchViewDelegate?

	override func viewDidLoad()
	{
		super.viewDidLoad()

		observations.observe(self, \.searchTerm)
			{
				(viewController, _) in viewController.scheduleUpdateSearch()
			}
	}

	override func prepare(for segue: NSStoryboardSegue, sender: Any?)
	{
		if segue.identifier == "embedResultsTabView",
			let tabViewController = segue.destinationController as? NSTabViewController
		{
			resultsTabView = tabViewController.tabView

			observations.observe(tabViewController, \.selectedTabViewItemIndex)
				{
					[weak self] (tabViewController, _) in self?.userSelection = nil
				}
		}
	}

	private func scheduleUpdateSearch()
	{
		userSelection = nil

		let selector = #selector(updateSearch)
		SearchViewController.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
		perform(selector, with: nil, afterDelay: 0.33)
	}

	@objc private func updateSearch()
	{
		guard let client = self.client else { return }

		searchTask?.task?.cancel()

		if searchTerm.isEmpty
		{
			handle(results: EmptyResults())
		}
		else
		{
			searchTask = dispatchSearch(client: client, searchTerm: searchTerm)
		}
	}

	private func dispatchSearch(client: ClientType, searchTerm: String) -> FutureTask?
	{
		let futurePromise = Promise<FutureTask>()
		let future = client.run(Search.search(query: searchTerm, resolve: true), resumeImmediately: true)
			{
				[weak self] result in

				DispatchQueue.main.async
					{
						guard let self = self else { return }

						if let task = futurePromise.value, self.searchTask === task
						{
							self.searchTask = nil
						}

						switch result
						{
						case .success(let response):
							let results = response.value
							self.handle(results: results)
						case .failure(let error): self.handle(error: error)
						}
					}
			}

		futurePromise.value = future
		return future
	}

	private func handle(results: ResultsType)
	{
		guard
			let instance = self.instance,
			let tabViewItems = resultsTabView?.tabViewItems
			else { return }

		for item in tabViewItems
		{
			guard let resultsPresenter = item.viewController as? SearchResultsPresenter else { continue }
			resultsPresenter.set(results: results, instance: instance)
			resultsPresenter.delegate = self
		}
	}

	private func handle(error: Error)
	{
		handle(results: EmptyResults())
	}

	@IBAction func cancel(_ sender: Any?)
	{
		view.window?.dismissSheetOrClose(modalResponse: .cancel)
	}

	@IBAction func showSelection(_ sender: Any?)
	{
		guard let selection = userSelection else { return }
		view.window?.dismissSheetOrClose(modalResponse: .continue)
		searchDelegate?.searchView(self, userDidSelect: selection)
	}
}

extension SearchViewController: SearchResultsPresenterDelegate
{
	func searchResultsPresenter(_ presenter: SearchResultsPresenter,
								userDidSelect selection: SearchResultSelection?)
	{
		userSelection = selection
	}

	func searchResultsPresenter(_ presenter: SearchResultsPresenter,
								userDidDoubleClick selection: SearchResultSelection)
	{
		assert(selection == userSelection)
		showSelection(nil)
	}
}

extension SearchViewController: NSTabViewDelegate
{
	func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?)
	{
		userSelection = nil
	}
}

protocol SearchViewDelegate: AnyObject
{
	func searchView(_ searchView: SearchViewController, userDidSelect selection: SearchResultSelection)
}

protocol ResultsType
{
	var accounts: [Account] { get }
	var statuses: [Status] { get }
	var hashtags: [Tag] { get }
}

struct EmptyResults: ResultsType
{
	var accounts: [Account] { return [] }
	var statuses: [Status] { return [] }
	var hashtags: [Tag] { return [] }
}

extension Results: ResultsType {}
