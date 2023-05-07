//
//  InstancePickerView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 05.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import SwiftUI

struct InstancePickerView: View {
	@State var instanceName: String

//	@State var languages = ["German", "English"]
	@State var selectedLanguage: String
	@State var selectedCategory: String

	@ObservedObject var viewModel: InstancePickerViewModel

	var body: some View {
		VStack(alignment: .leading) {
			Text("Type an instance address:")
				.font(.title3)

			TextField("Hello", text: $instanceName)
				.padding(.bottom, 20)

			Text("Or, pick from this list of popular instances:")
				.font(.title3)

			Picker("", selection: $selectedLanguage) {
				//				ForEach(languages) {
				//					language in
				//
				//					Text(language)
				//				}

				ForEach(viewModel.languages, id: \.locale) {
//				ForEach(["German", "English"], id: \.self) {
					language in

					Text(language.language ?? language.locale)
						.tag(language.locale)
				}
			}
			// .pickerStyle(.radioGroup)
			.scaledToFit()

			Picker("", selection: $selectedCategory) {
				ForEach(viewModel.categories, id: \.category) {
					category in

					Text(category.category)
						.tag(category.category)
				}
			}
			.scaledToFit()
			
			List {
				ForEach(viewModel.servers, id: \.domain) {
					server in
					
					VStack(alignment: .leading) {
						Text(server.domain)
							.bold()
					
						Text(server.description)
							.font(.subheadline)
							.foregroundColor(.secondary)
						
						HStack {
							Image.init(systemName: "person.3.fill")
							Text("\(server.totalUsers)")
						}
					}
				}
			}

//			Button("I agree to connect to joinmastodon.org") {
//
//			}
		}
		.task {
			await viewModel.refresh()
		}
	}
}

struct InstancePickerView_Previews: PreviewProvider {
	static var previews: some View {
		InstancePickerView(instanceName: "norden.social",
		                   selectedLanguage: "",
		                   selectedCategory: "All",
		                   viewModel: InstancePickerViewModel())
	}
}
