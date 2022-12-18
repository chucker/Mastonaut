//
//  Appearance.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 18.11.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import SwiftUI
import CoreTootin

struct AppearancePreferencesView: View {
	@State var appearance: MastonautPreferences.Appearance

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
		}
		.onChange(of: appearance) { newValue in
			Preferences.appearance = newValue
		}
	}
}

struct AppearancePreferencesView_Previews: PreviewProvider {
    static var previews: some View {
		AppearancePreferencesView(appearance: .dark)
    }
}
