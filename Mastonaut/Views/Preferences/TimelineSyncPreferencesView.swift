//
//  TimelineSyncPreferencesView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 13.04.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import CoreTootin
import SwiftUI

enum TimelineSyncMode: Int {
	case disabled
	case icloud
	case mastodon
	
	public var localizedTitle: String {
		switch self {
		case .disabled: return 🔠("Disabled")
		case .icloud: return 🔠("iCloud")
		case .mastodon: return 🔠("Mastodon")
		}
	}
	
	public var localizedRemarks: String {
		switch self {
		case .disabled: return ""
		case .icloud: return 🔠("Syncs your position across Macs running Mastonaut.")
		case .mastodon: return 🔠("Syncs your position across any Mastodon client that supports it.")
		}
	}
	
	public var warnings: String {
		switch self {
		case .disabled: return ""
		case .icloud: return ""
		case .mastodon: return 🔠("Not fully compatible with the Mastodon web interface.")
		}
	}
}

struct TimelineSyncPreferencesView: View {
	@AppStorage("$timelineSyncMode") var timelineSyncMode: TimelineSyncMode = .disabled

	var body: some View {
		VStack(alignment: .leading) {
			Text("Sync home timeline position via:")
			
			Picker("", selection: $timelineSyncMode) {
				Text(TimelineSyncMode.disabled.localizedTitle)
					.tag(TimelineSyncMode.disabled)

				VStack(alignment: .leading) {
					let mode = TimelineSyncMode.icloud
					
					Text(mode.localizedTitle)
						.tag(mode)
					
					Text(mode.localizedRemarks)
						.font(.subheadline)
						.foregroundColor(.secondary)
				}
				
				VStack(alignment: .leading) {
					let mode = TimelineSyncMode.mastodon
					
					Text(mode.localizedTitle)
						.tag(mode)

					Text(mode.localizedRemarks)
						.font(.subheadline)
						.foregroundColor(.secondary)
					
					HStack {
						Image(systemName: "exclamationmark.triangle")
						
						Text(mode.warnings)
							.font(.subheadline)
							.foregroundColor(.secondary)
							.padding(.leading, -5)
					}
				}
			}
			.pickerStyle(.radioGroup)
			
			Text("If enabled, other compatible clients will jump to where you left off.")
				.font(.subheadline)
									.foregroundColor(.secondary)
									.padding(.top, 20)
		}
	}
}

struct TimelineSyncPreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		TimelineSyncPreferencesView()
	}
}
