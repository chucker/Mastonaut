//
//  StatusComposerAttachmentsView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 03.12.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import SwiftUI

struct ComposerAttachment: Identifiable {
	let id: String

	var description: String = ""
}

struct StatusComposerAttachmentsView: View {
	@State var attachments: [ComposerAttachment]

	var body: some View {
		ForEach(attachments) { attachment in
			HStack {
				Text(attachment.id)
					.padding()
					.border(.green, width: 10)

				Text(attachment.description)
			}
		}
	}
}

struct SwiftUIView_Previews: PreviewProvider {
	static var previews: some View {
		var attachmentWithDescription = ComposerAttachment(id: "2")
		attachmentWithDescription.description = "Hello, this is some text"

		let noAttachments = [ComposerAttachment]()
		let oneAttachment: [ComposerAttachment] = [ComposerAttachment(id: "1")]
		let threeAttachments: [ComposerAttachment] = [ComposerAttachment(id: "1"), attachmentWithDescription, ComposerAttachment(id: "3")]

		return VStack {
			StatusComposerAttachmentsView(attachments: noAttachments)
				.padding(.all, 10)

			StatusComposerAttachmentsView(attachments: oneAttachment)
				.padding(.all, 10)

			StatusComposerAttachmentsView(attachments: threeAttachments)
				.padding(.all, 10)
		}
	}
}
