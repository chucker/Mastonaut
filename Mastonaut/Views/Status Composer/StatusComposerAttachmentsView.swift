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

	var thumbnailImage: NSImage?

	let upload: Upload?

	static func fromUpload(_ upload: Upload) -> ComposerAttachment {
		return ComposerAttachment(id: upload.fileName ?? "test", description: upload.fileName ?? "desc", type: .image, upload: upload)
	}
}

class ComposerAttachmentCollection: ObservableObject {
	@Published var items: [ComposerAttachment]

	init() {
		self.items = []
	}

	func replaceItems(_ newItems: [Upload]) {
		items.removeAll()

		for item in newItems {
			let composerAttachment = ComposerAttachment.fromUpload(item)

			items.append(composerAttachment)
		}
	}

	func getItemForUpload(_ upload: Upload) -> ComposerAttachment? {
		return items.first { $0.upload == upload }
	}
}

struct StatusComposerAttachmentsView: View {
	@StateObject var attachments = ComposerAttachmentCollection()

	var body: some View {
		let count = attachments.items.count

		ForEach($attachments.items) { $attachment in
			Divider()

			HStack(alignment: .top) {
				VStack {
					ZStack {
						if (attachment.thumbnailImage != nil) {
							Image(nsImage: attachment.thumbnailImage!)
							//						Text(attachment.id)
								.padding()
								.background(.secondary)
							//											.frame(width: 32, height: 32)
						}
						
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

				TextField("Describe this attachment", text: $attachment.description)

				Spacer()
			}
		}
//		.background(.blue)
//		.frame(minWidth: 534, minHeight: 100)
	}
}

struct SwiftUIView_Previews: PreviewProvider {
	static var previews: some View {
		var attachmentWithMovieMetadata = ComposerAttachment(id: "3", type: .video, upload: nil)
		attachmentWithMovieMetadata.metadata = "7s"

		var attachmentWithDescription = ComposerAttachment(id: "2", type: .image, upload: nil)
		attachmentWithDescription.description = "Hello, this is some text with a lot of words. We "

		let noAttachments = ComposerAttachmentCollection()

		let oneAttachment = ComposerAttachmentCollection()
		oneAttachment.items.append(ComposerAttachment(id: "1", type: .image, upload: nil))

		let threeAttachments = ComposerAttachmentCollection()
		threeAttachments.items.append(ComposerAttachment(id: "1", type: .image, upload: nil))
		threeAttachments.items.append(attachmentWithDescription)
		threeAttachments.items.append(attachmentWithMovieMetadata)

		return VStack {
			StatusComposerAttachmentsView(attachments: noAttachments)
			// .padding(.all, 10)

			StatusComposerAttachmentsView(attachments: oneAttachment)
			// .padding(.all, 10)

			StatusComposerAttachmentsView(attachments: threeAttachments)
			// .padding(.all, 10)
		}
	}
}
