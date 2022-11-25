//
//  AppKitSwiftUIIntegration.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 25.11.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import Foundation
import SwiftUI

class AppKitSwiftUIIntegration {
	public static func hostSwiftUIView<TSwiftUIView: View>(_ swiftView: TSwiftUIView, inView nsView: NSView) {
		let hostingView: NSHostingView<TSwiftUIView> = NSHostingView(rootView: swiftView)
		nsView.addSubview(hostingView)
		
		hostingView.translatesAutoresizingMaskIntoConstraints = false
		hostingView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor).isActive = true
		hostingView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor).isActive = true
		hostingView.topAnchor.constraint(equalTo: nsView.topAnchor).isActive = true
		hostingView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor).isActive = true
	}
}
