//
//  InstancePickerViewModel.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 06.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

class InstancePickerViewModel: ObservableObject {
	@Published var languages = [Language]()
	@Published var categories = [Category]()
	
	@MainActor
	func refresh() async {
		await refreshLanguages()
		await refreshCategories()
		// TODO: await refreshServers()
	}
	
	private func refreshLanguages() async {
		do {
			let (data, response) = try await URLSession.shared.data(from: JoinMastodonInstanceDirectory.languagesEndpointURL)
			
			guard let httpResponse = response as? HTTPURLResponse,
			      httpResponse.statusCode == 200
			else {
				return
			}
			
			languages = try JSONDecoder()
				.decode([Language].self, from: data)
				.filter { !($0.language?.isEmpty ?? true) }
				.sorted { $0.language! < $1.language! }
			
			languages.insert(Language(locale: "", language: "All", serversCount: 0), at: 0)
		}
		catch {}
	}
	
	private func refreshCategories() async {
		do {
			let (data, response) = try await URLSession.shared.data(from: JoinMastodonInstanceDirectory.categoriesEndpointURL)
			
			guard let httpResponse = response as? HTTPURLResponse,
			      httpResponse.statusCode == 200
			else {
				return
			}
			
			categories = try JSONDecoder()
				.decode([Category].self, from: data)
				.sorted { $0.category < $1.category }
			
			categories.insert(Category(category: "All", serversCount: 0), at: 0)
		}
		catch {}
	}
}
