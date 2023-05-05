//
//  AcknowledgmentView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 03.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import SwiftUI

struct AcknowledgementView: View {
	@State var viewModel: Acknowledgement

	var body: some View {
		ScrollView {
			VStack {
				Text(viewModel.title)
					.font(.title2)
					.padding(.bottom, 5)

				if let url = viewModel.url {
					Link("Website",
					     destination: URL(string: url)!)
						.padding(.bottom, 10)
				}

				if let text = viewModel.text {
					Text(text)
				}
			}.padding(10)
		}
	}
}

struct AcknowledgmentView_Previews: PreviewProvider {
	static var previews: some View {
		let viewModel = Acknowledgement(title: "Hello",
		                                text: "Goodbye",
		                                url: "http://example.com")

		AcknowledgementView(viewModel: viewModel)
	}
}
