//
//  PullToRefreshInnerView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 25.11.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import SwiftUI

struct PullToRefreshInnerView: View {
	@State var percentage : Double
	
    var body: some View {
		VStack {
			Spacer()
			
			if (percentage < 99) {
				Image(systemName: "arrow.clockwise")
					.rotationEffect(Angle.degrees(percentage) * 3)
			}
		}
	}
}

struct PullToRefreshInnerView_Previews: PreviewProvider {
    static var previews: some View {
		VStack {
			PullToRefreshInnerView(percentage: 0)
			PullToRefreshInnerView(percentage: 20)
			PullToRefreshInnerView(percentage: 80)
			PullToRefreshInnerView(percentage: 100)
		}
    }
}
