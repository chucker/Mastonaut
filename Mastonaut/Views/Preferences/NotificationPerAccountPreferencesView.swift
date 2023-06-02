//
//  NotificationPerAccountPreferencesView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 26.11.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import SwiftUI
import CoreTootin

@available(macOS 12.0, *)
struct NotificationPerAccountPreferencesView: View {
	let columns = [
		GridItem(.fixed(140), alignment: .topTrailing),
		GridItem(.flexible(), alignment: .leading),
	]
	
	var accountPreferences: AccountPreferences?
	var accountNotificationPreferences: AccountNotificationPreferences?

	@State var notificationDisplayMode: AccountPreferences.NotificationDisplayMode
	
	@State var notificationDetailMode: AccountPreferences.NotificationDetailMode
	
	@State private var showingConfigureTypesSheet = false
	
    var body: some View {
		ScrollView {
			VStack {
				Text("The following options are account-specific:")
					.font(.system(size: 13, weight: .semibold))
					.frame(maxWidth: .infinity, alignment: .center)
					.padding(.bottom, 10)
				
				LazyVGrid(columns: columns) {
					Text("Show Notifications:")
						.padding(.top, 2)
					
					VStack(alignment: .leading) {
						Picker("", selection: $notificationDisplayMode) {
							Text("Always").tag(AccountPreferences.NotificationDisplayMode.always)
							Text("Never").tag(AccountPreferences.NotificationDisplayMode.never)
							Text("When this account is active").tag(AccountPreferences.NotificationDisplayMode.whenActive)
						}
						.scaledToFit()
						.padding(.horizontal, -8)
						
						Text("Selecting 'When this account is active' will cause Mastonaut to only show notifications if you have at least one open window where this account is selected.")
							.font(.system(size: 11))
							.foregroundColor(.secondary)
							.padding(.top, 1)
					}
					.padding(.bottom, 10)
					
					Text("Notification Types:")
						.padding(.top, 2)

					HStack {
						// we _could_ summarize here which ones have been enabled
						//Text("All")
						
						Button("Configure…") {
							showingConfigureTypesSheet.toggle()
						}
						.sheet(isPresented: $showingConfigureTypesSheet) {
							NotificationTypeFilterPreferencesView(accountNotificationPreferences: accountNotificationPreferences!, accountName: accountPreferences!.account?.username ?? "(unknown)",
																  
																  showMentions: accountNotificationPreferences!.showMentions,
																  showStatuses: accountNotificationPreferences!.showStatuses,
																  
																  showNewFollowers: accountNotificationPreferences!.showNewFollowers,
																  showFollowRequests: accountNotificationPreferences!.showFollowRequests,
																  
																  showBoosts: accountNotificationPreferences!.showBoosts,
																  showFavorites: accountNotificationPreferences!.showFavorites,
																  
																  showPollResults: accountNotificationPreferences!.showPollResults,
																  
																  showEdits: accountNotificationPreferences!.showEdits,
																  
																  showAdminSignUps: accountNotificationPreferences!.showAdminSignUps,
																  showAdminReports: accountNotificationPreferences!.showAdminReports)
						}
					}
					.padding(.bottom, 10)

					Text("Show Post Details:")
					
					VStack(alignment: .leading) {
						Picker("", selection: $notificationDetailMode) {
							Text("Always").tag(AccountPreferences.NotificationDetailMode.always)
							Text("Never").tag(AccountPreferences.NotificationDetailMode.never)
							Text("When this account is active").tag(AccountPreferences.NotificationDetailMode.whenClean)
						}
						.scaledToFit()
						.padding(.horizontal, -8)
						
						Text("A status is considered safe-for-work if it has no content warning, no media flagged as sensitive, and is not tagged #NSFW.")
							.font(.system(size: 11))
							.foregroundColor(.secondary)
							.padding(.top, 1)
					}
				}
			}
			.onChange(of: notificationDisplayMode) { newValue in
				accountPreferences?.notificationDisplayMode = newValue
			}
			.onChange(of: notificationDetailMode) { newValue in
				accountPreferences?.notificationDetailMode = newValue
			}
		}
		.frame(minWidth: 480, minHeight: 260)
		.padding(.all, 10)
    }
}

@available(macOS 12.0, *)
struct NotificationPerAccountPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
		NotificationPerAccountPreferencesView(accountPreferences: nil,
											  notificationDisplayMode: .always,
											  notificationDetailMode: .always)
    }
}
