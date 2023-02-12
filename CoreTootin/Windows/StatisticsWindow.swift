//
//  StatisticsWindow.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 09.02.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import CoreTootin
import SwiftUI
import SwiftUICharts

struct StatisticsWindow: View {
	enum Group {
		case posted
		case boosted
		
		case postedSelectedUser
		case boostedSelectedUser
		
		func getData(forSelectedUsername: String?) -> GroupingData {
			switch self {
			case .posted:
				return GroupingData(title: "Posted", colour: ColourStyle(colour: .blue))
			case .boosted:
				return GroupingData(title: "Boosted", colour: ColourStyle(colour: .blue.opacity(0.6)))
				
			case .postedSelectedUser:
				return GroupingData(title: "Posted (@\(forSelectedUsername ?? ""))", colour: ColourStyle(colour: .orange))
			case .boostedSelectedUser:
				return GroupingData(title: "Boosted (@\(forSelectedUsername ?? ""))", colour: ColourStyle(colour: .orange.opacity(0.6)))
			}
		}
	}
	
	func getGroups(forSelectedUsername: String?) -> [GroupingData] {
		var groups = [
			Group.posted.getData(forSelectedUsername: nil),
			Group.boosted.getData(forSelectedUsername: nil),
		]
		
		if forSelectedUsername != nil {
			groups.append(Group.postedSelectedUser.getData(forSelectedUsername: forSelectedUsername))
			groups.append(Group.boostedSelectedUser.getData(forSelectedUsername: forSelectedUsername))
		}
			
		return groups
	}
	
	@State var dataSetsByDayOfWeek: [StackedBarDataSet]
	@State var dataSetsByHourOfDay: [StackedBarDataSet]
	
	@State var userTotals: [Stats_StatusesByHour.AggregateStatusByUserResult]
	
	let accountPickerColumns = [
		GridItem(.flexible(), alignment: .trailing),
		GridItem(.flexible(), alignment: .leading),
	]
	
	var accountsService: AccountsService?
	
	@State private var account: String?
	
	@State private var selectedUser: Stats_StatusesByHour.AggregateStatusByUserResult.ID?
	@State private var sortOrder = [KeyPathComparator(\Stats_StatusesByHour.AggregateStatusByUserResult.username)]

	init(accountsService: AccountsService?) {
		self.userTotals = Stats_StatusesByHour.getCountsByUser(context: AppDelegate.shared.managedObjectContext)
		
		self.accountsService = accountsService
		
		self.dataSetsByDayOfWeek = StatisticsWindow.fetchDataSetsByDayOfWeek(username: nil)
		self.dataSetsByHourOfDay = StatisticsWindow.fetchDataSetsByHourOfDay(username: nil)
	}
	
	static func fetchDataSetsByDayOfWeek(username: String?) -> [StackedBarDataSet] {
		let stats = Stats_StatusesByHour.getCountsByDayOfWeek(context: AppDelegate.shared.managedObjectContext, forUsername: username)
		
		var result = [StackedBarDataSet]()
		
		for s in stats {
			result.append(StackedBarDataSet(dataPoints: [
				StackedBarDataPoint(value: Double(s.postCount), description: "Hello", group: Group.posted.getData(forSelectedUsername: username)),
				StackedBarDataPoint(value: Double(s.boostCount), description: "Hello", group: Group.boosted.getData(forSelectedUsername: username)),

				StackedBarDataPoint(value: Double(s.postCountSelectedUser), description: "Hello", group: Group.postedSelectedUser.getData(forSelectedUsername: username)),
				StackedBarDataPoint(value: Double(s.boostCountSelectedUser), description: "Hello", group: Group.boostedSelectedUser.getData(forSelectedUsername: username)),
			]))
		}
		
		return result
	}
	
	static func fetchDataSetsByHourOfDay(username: String?) -> [StackedBarDataSet] {
		let stats = Stats_StatusesByHour.getCountsByHourOfDay(context: AppDelegate.shared.managedObjectContext, forUsername: username)
		
		var result = [StackedBarDataSet]()
		
		for s in stats {
			result.append(StackedBarDataSet(dataPoints: [
				StackedBarDataPoint(value: Double(s.postCount), description: "Hello", group: Group.posted.getData(forSelectedUsername: username)),
				StackedBarDataPoint(value: Double(s.boostCount), description: "Hello", group: Group.boosted.getData(forSelectedUsername: username)),
				
				StackedBarDataPoint(value: Double(s.postCountSelectedUser), description: "Hello", group: Group.postedSelectedUser.getData(forSelectedUsername: username)),
				StackedBarDataPoint(value: Double(s.boostCountSelectedUser), description: "Hello", group: Group.boostedSelectedUser.getData(forSelectedUsername: username)),
			]))
		}
		
		return result
	}
	
	var body: some View {
		VStack {
			Text("Posts from past 7 days")
				.font(.title)
			
			LazyVGrid(columns: accountPickerColumns) {
				Text("Received for account:")
				Picker("", selection: $account) {
					if let accountsService {
						ForEach(accountsService.authorizedAccounts,
						        id: \.self) { account in
							Text(account.bestDisplayName)
								.tag(account)
						}
					}

					//					ForEach(["All Accounts",
				}
				.scaledToFit()
				.padding(.horizontal, -8)
			}
			
			Divider()

			let chartDataByDayOfWeek = StackedBarChartData(dataSets: StackedBarDataSets(dataSets: dataSetsByDayOfWeek), groups: getGroups(forSelectedUsername: selectedUser))

			Text("By Day of Week").font(.title2)
			StackedBarChart(chartData: chartDataByDayOfWeek)
				.id(chartDataByDayOfWeek.id)
				.frame(height: 100)

			Divider()

			let chartDataByHourOfDay = StackedBarChartData(dataSets: StackedBarDataSets(dataSets: dataSetsByHourOfDay), groups: getGroups(forSelectedUsername: selectedUser))

			Text("By Hour of Day").font(.title2)
			StackedBarChart(chartData: chartDataByHourOfDay)
				.legends(chartData: chartDataByHourOfDay)
				.id(chartDataByHourOfDay.id)
				.frame(height: 233) // compensate for height of legends
			
			Divider()
			
			Table(userTotals, selection: $selectedUser, sortOrder: $sortOrder) {
				TableColumn("User", value: \.username)
				
				TableColumn("Posts", value: \.postCount)
				TableColumn("Boosted by them", value: \.boostCount)
			}
			.onChange(of: sortOrder) {
				userTotals.sort(using: $0)
			}
			.onChange(of: selectedUser) { selected in
				self.dataSetsByDayOfWeek = StatisticsWindow.fetchDataSetsByDayOfWeek(username: selected)
				self.dataSetsByHourOfDay = StatisticsWindow.fetchDataSetsByHourOfDay(username: selected)
			}
		}
		.padding(.all, 10)
	}
}

struct StatisticsWindow_Previews: PreviewProvider {
	static var previews: some View {
		StatisticsWindow(accountsService: nil)
	}
}
