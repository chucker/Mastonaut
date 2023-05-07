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
		nsView.subviews.removeAll()

		let hostingView: NSHostingView<TSwiftUIView> = NSHostingView(rootView: swiftView)
		nsView.addSubview(hostingView)

		hostingView.translatesAutoresizingMaskIntoConstraints = false
		hostingView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor).isActive = true
		hostingView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor).isActive = true
		hostingView.topAnchor.constraint(equalTo: nsView.topAnchor).isActive = true
		hostingView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor).isActive = true
	}

	public static func makeSheet<TSwiftUIView: View>(forSwiftUIView swiftUIView: TSwiftUIView, contentRect: NSRect) -> NSWindow {
		var window = NSWindow(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
		window.contentView = NSHostingView(rootView: swiftUIView)
		return window
	}
}
