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
		
		var data: GroupingData {
			switch self {
			case .posted:
				return GroupingData(title: "Posted", colour: ColourStyle(colour: .blue))
			case .boosted:
				return GroupingData(title: "Boosted", colour: ColourStyle(colour: .blue.opacity(0.8)))
				
			case .postedSelectedUser:
				return GroupingData(title: "Posted (selected user)", colour: ColourStyle(colour: .orange))
			case .boostedSelectedUser:
				return GroupingData(title: "Boosted (selected user)", colour: ColourStyle(colour: .orange.opacity(0.8)))
			}
		}
	}
	
	let groups: [GroupingData] = [Group.posted.data, Group.boosted.data]
	
	var dataSetsByDayOfWeek: [StackedBarDataSet] {
		let stats = Stats_StatusesByHour.getCountsByDayOfWeek(context: AppDelegate.shared.managedObjectContext)
		
		var result = [StackedBarDataSet]()
		
		for s in stats {
			result.append(StackedBarDataSet(dataPoints: [
				StackedBarDataPoint(value: Double(s.postCount), description: "Hello", group: Group.posted.data),
				StackedBarDataPoint(value: Double(s.boostCount), description: "Hello", group: Group.boosted.data),

				StackedBarDataPoint(value: Double(s.postCountSelectedUser), description: "Hello", group: Group.postedSelectedUser.data),
				StackedBarDataPoint(value: Double(s.boostCountSelectedUser), description: "Hello", group: Group.boostedSelectedUser.data),
			]))
		}
		
		return result
	}
	
	var dataSetsByHourOfDay: [StackedBarDataSet] {
		let stats = Stats_StatusesByHour.getCountsByHourOfDay(context: AppDelegate.shared.managedObjectContext)
		
		var result = [StackedBarDataSet]()
		
		for s in stats {
			result.append(StackedBarDataSet(dataPoints: [
				StackedBarDataPoint(value: Double(s.postCount), description: "Hello", group: Group.posted.data),
				StackedBarDataPoint(value: Double(s.boostCount), description: "Hello", group: Group.boosted.data),
				
				StackedBarDataPoint(value: Double(s.postCountSelectedUser), description: "Hello", group: Group.postedSelectedUser.data),
				StackedBarDataPoint(value: Double(s.boostCountSelectedUser), description: "Hello", group: Group.boostedSelectedUser.data),
			]))
		}
		
		return result
	}
	
	let accountPickerColumns = [
		GridItem(.flexible(), alignment: .trailing),
		GridItem(.flexible(), alignment: .leading),
	]
	
	var accountsService: AccountsService?
	
	@State private var account: String?
	
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
			
			let chartDataByDayOfWeek = StackedBarChartData(dataSets: StackedBarDataSets(dataSets: dataSetsByDayOfWeek), groups: groups)
			
			Text("By Day of Week").font(.title2)
			StackedBarChart(chartData: chartDataByDayOfWeek)
				.frame(height: 100)
			
			Divider()
			
			let chartDataByHourOfDay = StackedBarChartData(dataSets: StackedBarDataSets(dataSets: dataSetsByHourOfDay), groups: groups)

			Text("By Hour of Day").font(.title2)
			StackedBarChart(chartData: chartDataByHourOfDay)
				.frame(height: 100)
		}
		.padding(.all, 10)
	}
}

struct StatisticsWindow_Previews: PreviewProvider {
	static var previews: some View {
		StatisticsWindow(accountsService: nil)
	}
}
