//
//  AcknowledgmentsView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 03.05.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import SwiftUI

class AcknowledgementsWindow: NSWindow {
	init() {
		super.init(contentRect: NSRect(x: 0, y: 0, width: 800, height: 500), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
		makeKeyAndOrderFront(nil)
		isReleasedWhenClosed = false
		styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
		title = "Acknowledgements"
		contentView = NSHostingView(rootView: AcknowledgementsView())
	}
}

struct AcknowledgementsView: View {
	@StateObject var viewModel = AcknowledgementsViewModel()

	var body: some View {
		NavigationView {
			List(viewModel.entries) { acknowledgement in
				NavigationLink(acknowledgement.title, destination: AcknowledgementView(viewModel: acknowledgement))
			}.frame(minWidth: 200)
			Text("Select an item")
		}
	}
}

struct AcknowledgementsView_Previews: PreviewProvider {
	static var previews: some View {
		AcknowledgementsView()
	}
}
