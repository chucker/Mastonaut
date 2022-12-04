//
//  StatusComposerAttachmentsView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 03.12.22.
//  Copyright © 2022 Bruno Philipe. All rights reserved.
//

import MastodonKit
import SwiftUI

struct ComposerAttachment: Identifiable {
	let id: String

	var description: String = ""

	let type: AttachmentType
	var metadata: String = ""
}

struct StatusComposerAttachmentsView: View {
	@State var attachments: [ComposerAttachment]

	var body: some View {
		ForEach(attachments) { attachment in
			HStack(alignment: .top) {
				VStack {
					ZStack {
						Text(attachment.id)
							.padding()
							.border(.green, width: 10)

						Button(action: {}) {
							Image(systemName: "xmark.circle.fill")
								.padding(.leading, 25)
								.padding(.bottom, 25)
								.accessibilityLabel("Delete attachment")
						}
						.buttonStyle(.borderless)
					}

					HStack {
						switch attachment.type {
						case .image:
							Image(systemName: "camera")
						case .video, .gifv:
							Image(systemName: "video")
						default:
							EmptyView()
						}

						Text(attachment.metadata)
							.font(.system(size: 11))
					}
				}

				Text(attachment.description)

				Spacer()
			}
		}
	}
}

struct SwiftUIView_Previews: PreviewProvider {
	static var previews: some View {
		var attachmentWithMovieMetadata = ComposerAttachment(id: "3", type: .video)
		attachmentWithMovieMetadata.metadata = "7s"

		var attachmentWithDescription = ComposerAttachment(id: "2", type: .image)
		attachmentWithDescription.description = "Hello, this is some text"

		let noAttachments = [ComposerAttachment]()
		let oneAttachment: [ComposerAttachment] = [ComposerAttachment(id: "1", type: .image)]
		let threeAttachments: [ComposerAttachment] = [ComposerAttachment(id: "1", type: .image), attachmentWithDescription, attachmentWithMovieMetadata]

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
