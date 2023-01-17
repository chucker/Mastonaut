//
//  StatusPrivacyPreferencesView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 18.12.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import CoreTootin
import SwiftUI

struct StatusPrivacyPreferencesView: View {
	@AppStorage("defaultStatusAudience") var defaultStatusAudience: MastonautPreferences.StatusAudience = .public
	@AppStorage("defaultReplyAudience") var defaultReplyAudience: MastonautPreferences.StatusAudience = .unlisted

	var preferences: MastonautPreferences?

	let columns = [
		GridItem(.fixed(260), alignment: .trailing),
		GridItem(.fixed(380), alignment: .leading),
	]

	var body: some View {
		LazyVGrid(columns: columns) {
			Text("Default status privacy:")
			Picker("", selection: $defaultStatusAudience) {
				ForEach([MastonautPreferences.StatusAudience.public,
				         MastonautPreferences.StatusAudience.unlisted,
				         MastonautPreferences.StatusAudience.private],
				        id: \.self) { audience in
					HStack {
						if let icon = audience.icon {
							Image(nsImage: icon)
						}
						Text(audience.localizedTitle)
					}
					.tag(audience)
				}
			}
			.scaledToFit()
			.padding(.horizontal, -8)

			Text("Default reply privacy:")
			Picker("", selection: $defaultReplyAudience) {
				ForEach([MastonautPreferences.StatusAudience.public,
				         MastonautPreferences.StatusAudience.unlisted,
				         MastonautPreferences.StatusAudience.private],
				        id: \.self) { audience in
					HStack {
						if let icon = audience.icon {
							Image(nsImage: icon)
						}
						Text(audience.localizedTitle)
					}
					.tag(audience)
				}
			}
			.scaledToFit()
			.padding(.horizontal, -8)

			Spacer()
			Text("Replies to private statuses will always default to private.")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
		// these seem to be needed to sync the changes back to MastonautPreferences https://stackoverflow.com/questions/71762758
		.onChange(of: defaultStatusAudience) { newValue in
			preferences?.defaultStatusAudience = newValue
		}
		.onChange(of: defaultReplyAudience) { newValue in
			preferences?.defaultReplyAudience = newValue
		}
		// AppKit layout hacks
		.padding(.trailing, 15)
		.frame(minHeight: 70)
	}
}

struct StatusPrivacyPreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		StatusPrivacyPreferencesView()
	}
}
