//
//  NotificationTypeFilterPreferencesView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 26.11.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import SwiftUI
import CoreTootin

struct NotificationTypeFilterPreferencesView: View {
	@Environment(\.dismiss) var dismiss
	
	// FIXME: this works, but can't we just bind the entity rather than each bool?
	@State var accountNotificationPreferences: AccountNotificationPreferences
	//	@FetchRequest(entity: AccountNotificationPreferences.entity, sortDescriptors: [])
		
	@State var accountName: String

	@State var showMentions: Bool
	@State var showStatuses: Bool

	@State var showNewFollowers: Bool
	@State var showFollowRequests: Bool

	@State var showBoosts: Bool
	@State var showFavorites: Bool

	@State var showPollResults: Bool

	@State var showEdits: Bool

	@State var showAdminSignUps: Bool
	@State var showAdminReports: Bool

    var body: some View {
		VStack(alignment: .leading) {
			Text("For account \(accountName), only show these notifications:")
				.font(.system(size: 13, weight: .semibold))
				.padding(.bottom, 10)
			
			VStack(alignment: .leading) {
				Toggle("Mentions", isOn: $showMentions)
//				Toggle("Statuses", isOn: $showStatuses)
				
//				Text("For people for whom you've specifically enabled notifications")
//					.font(.system(size: 11))
//					.foregroundColor(.secondary)
//					.padding(.leading, 20)
					.padding(.bottom, 10)

				Toggle("New followers", isOn: $showNewFollowers)
				Toggle("Follow requests", isOn: $showFollowRequests)
					.padding(.bottom, 10)

				Toggle("Boosts", isOn: $showBoosts)
				Toggle("Favorites", isOn: $showFavorites)
					.padding(.bottom, 10)

				Toggle("Poll results", isOn: $showPollResults)
					.padding(.bottom, 10)

//				Toggle("Edits", isOn: $showEdits)
//					.padding(.bottom, 10)
			}
			
//			VStack(alignment: .leading) {
//				Text("For admins:")
//							
//				Toggle("Sign-ups", isOn: $showAdminSignUps)
//					.padding(.leading, 10)
//				Toggle("Reports", isOn: $showAdminReports)
//					.padding(.leading, 10)
//					.padding(.bottom, 10)
//			}

			HStack {
//				Button("All") {
//					print("hello")
//				}
//				
//				Button("None") {
//					print("hello")
//				}
				
				Button("Done") {
					dismiss()
				}
				.frame(maxWidth: .infinity, alignment: .trailing)
			}
		}
		.padding(.all, 20)
	
		.onChange(of: showMentions) { newValue in
			accountNotificationPreferences.showMentions = newValue
		}
		.onChange(of: showStatuses) { newValue in
			accountNotificationPreferences.showStatuses = newValue
		}
		
		.onChange(of: showNewFollowers) { newValue in
			accountNotificationPreferences.showNewFollowers = newValue
		}
		.onChange(of: showFollowRequests) { newValue in
			accountNotificationPreferences.showFollowRequests = newValue
		}
		
		.onChange(of: showBoosts) { newValue in
			accountNotificationPreferences.showBoosts = newValue
		}
		.onChange(of: showFavorites) { newValue in
			accountNotificationPreferences.showFavorites = newValue
		}
		
		.onChange(of: showPollResults) { newValue in
			accountNotificationPreferences.showPollResults = newValue
		}

		.onChange(of: showEdits) { newValue in
			accountNotificationPreferences.showEdits = newValue
		}
		
		.onChange(of: showAdminSignUps) { newValue in
			accountNotificationPreferences.showAdminSignUps = newValue
		}
		.onChange(of: showAdminReports) { newValue in
			accountNotificationPreferences.showAdminReports = newValue
		}
    }
}

struct NotificationTypeFilterPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
		NotificationTypeFilterPreferencesView(accountNotificationPreferences: AccountNotificationPreferences(), accountName: "hello@example.com",
											  
											  showMentions: true,
											  showStatuses: true,
											  
											  showNewFollowers: true,
											  showFollowRequests: true,
											  
											  showBoosts: true,
											  showFavorites: true,
											  
											  showPollResults: true,
											  
											  showEdits: true,
											  
											  showAdminSignUps: true,
											  showAdminReports: true)
    }
}
