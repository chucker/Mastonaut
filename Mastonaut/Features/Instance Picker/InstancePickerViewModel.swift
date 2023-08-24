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
	@Published var servers = [Server]()

	@Published var selectedLanguage: String = "" {
		didSet { refreshFilteredServers() }
	}

	@Published var selectedCategory: String = "All" {
		didSet { refreshFilteredServers() }
	}

	@Published var filteredServers = [Server]()
	
	var instanceName: String = "" {
		didSet { refreshFilteredServers() }
	}

	func refreshFilteredServers() {
		filteredServers = servers
		
		if instanceName != "" {
			filteredServers.removeAll { !$0.domain.contains(instanceName) }
		}
		
		if selectedLanguage != "" {
			filteredServers.removeAll { !$0.languages.contains(selectedLanguage) }
		}
		
		if selectedCategory != "All" {
			filteredServers.removeAll { !$0.categories.contains(selectedCategory) }
		}
	}
		
	@MainActor
	func refresh() async {
		await refreshLanguages()
		await refreshCategories()
		await refreshServers()
		refreshFilteredServers()
	}
	
	@MainActor
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
	
	@MainActor
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
	
	@MainActor
	private func refreshServers() async {
		do {
			let (data, response) = try await URLSession.shared.data(from: JoinMastodonInstanceDirectory.serversEndpointURL)
			
			guard let httpResponse = response as? HTTPURLResponse,
			      httpResponse.statusCode == 200
			else {
				return
			}
			
			servers = try JSONDecoder()
				.decode([Server].self, from: data)
//				.sorted { $0.domain < $1.domain }
				.sorted { $0.totalUsers > $1.totalUsers }
		}
		catch {}
	}
}
