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
		
		var data: GroupingData {
			switch self {
			case .posted:
				return GroupingData(title: "Posted", colour: ColourStyle(colour: .blue))
			case .boosted:
				return GroupingData(title: "Boosted", colour: ColourStyle(colour: .blue.opacity(0.8)))
			}
		}
	}
	
	let groups: [GroupingData] = [Group.posted.data, Group.boosted.data]
	
	var dataSets: [StackedBarDataSet] {
		let stats = Stats_StatusesByHour.getCounts(context: AppDelegate.shared.managedObjectContext)
		
		var result = [StackedBarDataSet]()
		
		for s in stats {
			result.append(StackedBarDataSet(dataPoints: [
				StackedBarDataPoint(value: Double(s.postCount), description: "Hello", group: Group.posted.data),
				StackedBarDataPoint(value: Double(s.boostCount), description: "Hello", group: Group.boosted.data)
			]))
		}
		
		return result
	}
	
	var body: some View {
		let chartData = StackedBarChartData(dataSets: StackedBarDataSets(dataSets: dataSets), groups: groups)
		
		VStack {
			Text("Posts by Hour of Day").font(.title)
			StackedBarChart(chartData: chartData)
		}
		.padding(.all, 5)
	}
}

struct StatisticsWindow_Previews: PreviewProvider {
	static var previews: some View {
		StatisticsWindow()
	}
}
