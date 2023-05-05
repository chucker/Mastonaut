//
//  Appearance.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 18.11.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import CoreTootin
import FontPicker
import SwiftUI

struct FontSizePreferencesView: View {
	@State private var statusFont: NSFont = MastonautPreferences.instance.statusFont
	@State private var focusedStatusFont: NSFont = MastonautPreferences.instance.focusedStatusFont

	let columns = [
		GridItem(.fixed(260), alignment: .trailing),
		GridItem(.fixed(380), alignment: .leading),
	]

	var body: some View {
		LazyVGrid(columns: columns) {
			Text("Status font size:")

			HStack {
				FontPicker("", selection: $statusFont)
					.padding(.leading, -7) // FontPicker shows its own label, which we don't want

				Button("Reset") {
					statusFont = MastonautPreferences.defaultStatusFont
				}

				Text("\(statusFont.displayName ?? "(no font)") \(statusFont.pointSize, specifier: "%.0f")")
			}
			
			Text("Focused status font size:")

			HStack {
				FontPicker("", selection: $focusedStatusFont)
					.padding(.leading, -7) // FontPicker shows its own label, which we don't want

				Button("Reset") {
					focusedStatusFont = MastonautPreferences.defaultFocusedStatusFont
				}

				Text("\(focusedStatusFont.displayName ?? "(no font)") \(focusedStatusFont.pointSize, specifier: "%.0f")")
			}
		}
		.onChange(of: statusFont) { newValue in
			MastonautPreferences.instance.statusFont = newValue
		}
		.onChange(of: focusedStatusFont) { newValue in
			MastonautPreferences.instance.focusedStatusFont = newValue
		}
		// AppKit layout hacks
		.padding(.trailing, 15)
		.frame(minHeight: 70)
	}
}

struct FontSizePreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		FontSizePreferencesView()
	}
}
