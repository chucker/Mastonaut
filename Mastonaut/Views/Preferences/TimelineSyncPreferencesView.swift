//
//  TimelineSyncPreferencesView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 13.04.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import CoreTootin
import SwiftUI

struct TimelineSyncPreferencesView: View {
	@AppStorage("timelineSyncMode") var timelineSyncMode: MastonautPreferences.TimelineSyncMode = .disabled
	
	var preferences: MastonautPreferences?
	
	let columns = [
		GridItem(.fixed(260), alignment: .topTrailing),
		GridItem(.fixed(380), alignment: .leading),
	]

	var body: some View {
		LazyVGrid(columns: columns) {
			Text("Sync home timeline position via:")
			
			VStack(alignment: .leading) {
				Picker("", selection: $timelineSyncMode) {
					let mode1 = MastonautPreferences.TimelineSyncMode.disabled
					Text(mode1.localizedTitle)
						.tag(mode1)
						.padding(.bottom, 5)
					
					let mode2 = MastonautPreferences.TimelineSyncMode.icloud
					VStack(alignment: .leading) {
						Text(mode2.localizedTitle)
						
						Text(mode2.localizedRemarks)
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					.padding(.bottom, 5)
					.tag(mode2)

					let mode3 = MastonautPreferences.TimelineSyncMode.mastodon
					VStack(alignment: .leading) {
						Text(mode3.localizedTitle)
						
						Text(mode3.localizedRemarks)
							.font(.subheadline)
							.foregroundColor(.secondary)
						
						HStack {
							Image(systemName: "exclamationmark.triangle")
							
							Text(mode3.warnings)
								.font(.subheadline)
								.foregroundColor(.secondary)
								.padding(.leading, -5)
						}
					}
					.tag(mode3)
				}
				.pickerStyle(.radioGroup)
				
				Text("If enabled, other compatible clients will scroll to where you left off.")
					.font(.subheadline)
					.foregroundColor(.secondary)
					.padding(.top, 20)
					.padding(.leading, 8)
			}
		}
		.onChange(of: timelineSyncMode) { newValue in
			preferences?.timelineSyncMode = newValue
		}
		.frame(minWidth: 786, minHeight: 200)
	}
}

struct TimelineSyncPreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		TimelineSyncPreferencesView()
	}
}
