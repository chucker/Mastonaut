//
//  StatisticsWindow.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 09.02.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

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

	let data = StackedBarDataSets(dataSets: [
		StackedBarDataSet(dataPoints: [
			StackedBarDataPoint(value: 30, description: "One Three", group: Group.posted.data),
			StackedBarDataPoint(value: 40, description: "One Four", group: Group.boosted.data)
		]),
		  
		StackedBarDataSet(dataPoints: [
			StackedBarDataPoint(value: 40, description: "Two Three", group: Group.posted.data),
			StackedBarDataPoint(value: 60, description: "Two Four", group: Group.boosted.data)
		]),
		  
		StackedBarDataSet(dataPoints: [
			StackedBarDataPoint(value: 30, description: "Three Three", group: Group.posted.data),
			StackedBarDataPoint(value: 90, description: "Three Four", group: Group.boosted.data)
		]),
		  
		StackedBarDataSet(dataPoints: [
			StackedBarDataPoint(value: 20, description: "Four Three", group: Group.posted.data),
			StackedBarDataPoint(value: 50, description: "Four Four", group: Group.boosted.data)
		])
	])
	
	var body: some View {
		let chartData = StackedBarChartData(dataSets: data, groups: groups)
		
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
