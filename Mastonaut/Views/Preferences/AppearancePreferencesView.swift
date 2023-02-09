//
//  Appearance.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 18.11.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import CoreTootin
import SwiftUI

struct AppearancePreferencesView: View {
	@AppStorage("appearance") var appearance: MastonautPreferences.Appearance = .auto

	@AppStorage("areStatisticsEnabled") var areStatisticsEnabled: Bool = false

	var preferences: MastonautPreferences?

	let columns = [
		GridItem(.fixed(260), alignment: .trailing),
		GridItem(.fixed(380), alignment: .leading),
	]

	var body: some View {
		LazyVGrid(columns: columns) {
			Text("Appearance:")
			Picker("", selection: $appearance) {
				Text("System Default").tag(MastonautPreferences.Appearance.auto)
				Text("Light").tag(MastonautPreferences.Appearance.light)
				Text("Dark").tag(MastonautPreferences.Appearance.dark)
			}
			.pickerStyle(.radioGroup)
			.horizontalRadioGroupLayout()
			.padding(.horizontal, -8)

			Text("Statistics:")
				.padding(.top, 20)
			Toggle("Collect statistics on peoples' toots", isOn: $areStatisticsEnabled)
				.toggleStyle(.checkbox)
				.padding(.top, 20)

			Text("")
			Text("Statistics data is always kept local. It comprises a toot's author and date, but not its actual contents.")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
		.onChange(of: appearance) { newValue in
			Preferences.appearance = newValue
		}
		.onChange(of: areStatisticsEnabled) { newValue in
			preferences?.areStatisticsEnabled = newValue
		}
		// AppKit layout hacks
		.padding(.trailing, 15)
	}
}

struct AppearancePreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		AppearancePreferencesView(appearance: .dark)
	}
}
