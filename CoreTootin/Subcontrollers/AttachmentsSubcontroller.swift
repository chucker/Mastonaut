//
//  AttachmentsSubcontroller.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 07.03.19.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2019 Bruno Philipe.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

import AppKit
import MastodonKit

@objc public protocol StatusComposerController: AnyObject
{
	func updateSubmitEnabled()
	func showAttachmentError(message: String)
}

public class AttachmentsSubcontroller: NSObject
{
//	@IBOutlet private(set) weak var attachmentCollectionView: NSCollectionView!

	@IBOutlet private(set) var attachmentView: NSView!
	private var statusComposerAttachmentView: StatusComposerAttachmentsView?

	@IBOutlet private(set) var statusComposerController: StatusComposerController!

	public private(set) lazy var attachmentUploader = AttachmentUploader(delegate: self)

	private let descriptionPopoverViewController = AttachmentDescriptionViewController()

	private var lastOpenedDescriptionAttachmentIndex: Array<Upload>.Index?
	private let descriptionCharacterLimit = 420
	private var uploadsWithDescriptionUpdateError: Set<Upload> = []

	public var showProposedAttachmentItem: Bool = false
	{
		didSet
		{
//			if showProposedAttachmentItem, !oldValue
//			{
//				attachmentCollectionView.animator().insertItems(at: [IndexPath(item: attachments.count, section: 0)])
//			}
//			else if !showProposedAttachmentItem, oldValue
//			{
//				attachmentCollectionView.animator().deleteItems(at: [IndexPath(item: attachments.count, section: 0)])
//			}
		}
	}

	public var client: ClientType?
	{
		didSet { dispatchAllPendingUploads() }
	}

	override public func awakeFromNib()
	{
		super.awakeFromNib()
		
		var attachmentWithMovieMetadata = ComposerAttachment(id: "3", type: .video)
		attachmentWithMovieMetadata.metadata = "7s"

		var attachmentWithDescription = ComposerAttachment(id: "2", type: .image)
		attachmentWithDescription.description = "Hello, this is some text with a lot of words. We "

		let noAttachments = [ComposerAttachment]()
		let oneAttachment: [ComposerAttachment] = [ComposerAttachment(id: "1", type: .image)]
		let threeAttachments: [ComposerAttachment] = [ComposerAttachment(id: "1", type: .image), attachmentWithDescription, attachmentWithMovieMetadata]
		
		statusComposerAttachmentView = StatusComposerAttachmentsView(attachments: threeAttachments)

		AppKitSwiftUIIntegration.hostSwiftUIView(statusComposerAttachmentView, inView: attachmentView)

//		attachmentCollectionView.register(AttachmentItem.self,
//		                                  forItemWithIdentifier: ReuseIdentifiers.attachment)
//
//		attachmentCollectionView.register(ProposedAttachmentItem.self,
//		                                  forItemWithIdentifier: ReuseIdentifiers.proposedAttachment)

		descriptionPopoverViewController.descriptionStringValueDidChangeHandler =
		{
			[unowned self] in self.updateRemainingDescriptionCountLabel()
		}

		descriptionPopoverViewController.didClickSubmitChangeHandler =
		{
			[unowned self] in self.submitDescription()
		}

		descriptionPopoverViewController.loadView()
	}

	@objc public dynamic var attachmentCount: Int
	{
		return attachments.count
	}

	public private(set) var attachments: [Upload] = []
	{
		willSet
		{
			willChangeValue(for: \AttachmentsSubcontroller.attachmentCount)
		}

		didSet
		{
			didChangeValue(for: \AttachmentsSubcontroller.attachmentCount)
		}
	}

	public var hasAttachmentsPendingUpload: Bool
	{
		return attachments.filter { $0.attachment == nil }.count != 0
	}

	public func reset()
	{
		let allItemIndexPaths = Set((0..<attachments.count).map { IndexPath(item: $0, section: 0) })
		attachments.removeAll()
//		attachmentCollectionView.animator().deleteItems(at: allItemIndexPaths)
		uploadsWithDescriptionUpdateError = []
		lastOpenedDescriptionAttachmentIndex = nil
	}

	public func discardAllAttachmentsAndUploadAgain()
	{
		uploadsWithDescriptionUpdateError = []
		lastOpenedDescriptionAttachmentIndex = nil

		attachments.forEach { $0.discardAttachment() }

		if let client = client
		{
			attachmentUploader.startUploading(uploads: attachments, for: client)
		}
	}

	public func collectionViewItem(for upload: Upload) -> AttachmentItem?
	{
		return nil
//		guard
//			let index = attachments.firstIndex(of: upload),
//			attachmentCollectionView.indexPathsForVisibleItems().contains(IndexPath(item: index, section: 0))
//		else
//		{
//			return nil
//		}
//
//		return attachmentCollectionView.item(at: IndexPath(item: index, section: 0)) as? AttachmentItem
	}

	public func addAttachments(_ urls: [URL])
	{
		guard !urls.isEmpty else { return }

		var validUploads: [Upload] = []
		var failedURLs: [URL] = []

		for url in urls
		{
			if let upload = Upload(fileUrl: url, imageRestrainer: attachmentUploader.imageRestrainer)
			{
				validUploads.append(upload)
			}
			else
			{
				failedURLs.append(url)
			}
		}

		if !failedURLs.isEmpty
		{
			// Show Error
		}

		add(uploads: validUploads)
	}

	public func addAttachments(_ images: [NSImage])
	{
		add(uploads: images.map { Upload(image: $0) })
	}

	@discardableResult
	public func addAttachments(_ attachments: [Attachment]) -> [Upload]
	{
		let uploads = attachments.map { Upload(attachment: $0) }
		add(uploads: uploads)
		return uploads
	}

	private func add(uploads: [Upload])
	{
		attachments.append(contentsOf: uploads)

		if let client = client
		{
			// Only start processing after uploads are stored in the attachments array so we can track
			// their idexes on the delegate method calls.
			attachmentUploader.startUploading(uploads: uploads, for: client)
		}

		let totalAttachments = attachments.count
		let insertedItems = (totalAttachments - uploads.count)..<totalAttachments
		let insertedSet = Set(insertedItems.map { IndexPath(item: $0, section: 0) })

//		attachmentCollectionView.animator().insertItems(at: insertedSet)
	}

	public func removeAttachment(_ attachment: Upload)
	{
		guard let index = attachments.firstIndex(of: attachment) else { return }
		attachmentUploader.cancel(upload: attachments.remove(at: index))
//		attachmentCollectionView.animator().deleteItems(at: [IndexPath(item: index, section: 0)])
	}

	public func update(thumbnail: NSImage, for upload: Upload)
	{
//		guard let index = attachments.firstIndex(of: upload) else { return }
//		(attachmentCollectionView.item(at: index) as? AttachmentItem)?.image = thumbnail
	}

	private func updateRemainingDescriptionCountLabel()
	{
		let remainingCount = descriptionCharacterLimit - descriptionPopoverViewController.descriptionStringValue.count
		descriptionPopoverViewController.set(remainingCount: remainingCount)

		let submitEnabled = remainingCount >= 0 && remainingCount < descriptionCharacterLimit
		descriptionPopoverViewController.set(submitEnabled: submitEnabled)
	}

	private func dispatchAllPendingUploads()
	{
		guard let client = client else { return }
		let pendingUploads = attachments.filter { $0.needsUploading }
		attachmentUploader.startUploading(uploads: pendingUploads, for: client)
	}

	fileprivate enum ReuseIdentifiers
	{
		static let attachment = NSUserInterfaceItemIdentifier(rawValue: "attachment")
		static let proposedAttachment = NSUserInterfaceItemIdentifier(rawValue: "proposed")
	}
}

extension AttachmentsSubcontroller: NSCollectionViewDataSource
{
	public func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int
	{
		return attachments.count + (showProposedAttachmentItem ? 1 : 0)
	}

	public func collectionView(_ collectionView: NSCollectionView,
	                           itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem
	{
		guard indexPath.item < attachments.count
		else
		{
			return collectionView.makeItem(withIdentifier: ReuseIdentifiers.proposedAttachment, for: indexPath)
		}

		let item = collectionView.makeItem(withIdentifier: ReuseIdentifiers.attachment, for: indexPath)

		if let attachmentItem = item as? AttachmentItem
		{
			let attachment = attachments[indexPath.item]

			attachment.loadMetadata
			{
				[weak collectionView] metadata in

				DispatchQueue.main.async
				{
					(collectionView?.item(at: indexPath) as? AttachmentItem)?.set(itemMetadata: metadata)
				}
			}

			attachment.loadThumbnail
			{
				[weak collectionView] thumbnail in

				DispatchQueue.main.async
				{
					(collectionView?.item(at: indexPath) as? AttachmentItem)?.image = thumbnail
				}
			}

			attachmentItem.removeButtonAction = { [unowned self] in self.removeAttachment(attachment) }
			attachmentItem.descriptionButtonAction = { [unowned self] in self.showDescriptionEditor(for: attachment) }
			attachmentItem.isPendingSetDescription = attachmentUploader.isPendingCompletion(forSettingDescriptionOf: attachment)
		}

		return item
	}

	private func showDescriptionEditor(for attachment: Upload)
	{
		return
//		guard let index = attachments.firstIndex(of: attachment)
//		else
//		{
//			return
//		}
//
//		let indexPath = IndexPath(item: index, section: 0)
//
//		guard attachmentCollectionView.indexPathsForVisibleItems().contains(indexPath)
//		else
//		{
//			return
//		}
//
//		lastOpenedDescriptionAttachmentIndex = index
//
//		descriptionPopoverViewController.set(description: attachment.attachment?.description ?? "",
//		                                     hasError: uploadsWithDescriptionUpdateError.contains(attachment))
//
//		descriptionPopoverViewController.showPopover(relativeTo: attachmentCollectionView.frameForItem(at: index),
//		                                             of: attachmentCollectionView)
//
//		updateRemainingDescriptionCountLabel()
	}

	private func submitDescription()
	{
		guard
			let client = client,
			let index = lastOpenedDescriptionAttachmentIndex,
			index < attachments.count, index >= 0
		else
		{
			return
		}

		lastOpenedDescriptionAttachmentIndex = nil

		let attachment = attachments[index]
		let descriptionString = descriptionPopoverViewController.descriptionStringValue
		descriptionPopoverViewController.set(description: "", hasError: false)
		updateRemainingDescriptionCountLabel()

		let nullableDescription = descriptionString.isEmpty ? nil : descriptionString
		attachmentUploader.set(description: nullableDescription, of: attachment, for: client)
		statusComposerController.updateSubmitEnabled()

		collectionViewItem(for: attachment)?.isPendingSetDescription = true
	}
}

extension AttachmentsSubcontroller: AttachmentUploaderDelegate
{
	public func attachmentUploader(_: AttachmentUploader, finishedUploading upload: Upload)
	{
		DispatchQueue.main.async
		{
			[weak self] in
			self?.collectionViewItem(for: upload)?.set(progressIndicatorState: .uploaded)
			self?.statusComposerController.updateSubmitEnabled()
		}
	}

	public func attachmentUploader(_: AttachmentUploader, updatedProgress progress: Double, for upload: Upload)
	{
		DispatchQueue.main.async
		{
			[weak self] in
			self?.collectionViewItem(for: upload)?.set(progressIndicatorState: .uploading(progress: progress))
		}
	}

	public func attachmentUploader(_: AttachmentUploader, produced error: AttachmentUploader.UploadError, for upload: Upload)
	{
		let errorMessage: String

		switch error
		{
		case .noKnownMimeForUTI:
			errorMessage = 🔠("compose.attachment.upload.noknownuti",
			                 upload.fileName ?? "<error>",
			                 "HEIC, PNG, JPG, JPG2000, TIFF, BMP, GIF, MOV, MP4")

		case .failedEncodingResizedImage:
			let maxSize = AttachmentUploader.maxAttachmentImageSize
			let maxMegaPixels = Int(maxSize.area / 1_000_000)
			errorMessage = 🔠("compose.attachment.upload.badresizeencode",
			                 upload.fileName ?? "<error>",
			                 maxMegaPixels, maxSize.width, maxSize.height)

		case .encodeError(let encodeError):
			errorMessage = 🔠("compose.attachment.encode",
			                 upload.fileName ?? "<error>",
			                 encodeError.localizedDescription)

		case .serverError(let serverError):
			if (serverError as NSError).code == NSURLErrorCancelled
			{
				// Not an error: user cancelled upload.
				return
			}

			errorMessage = 🔠("compose.attachment.server",
			                 upload.fileName ?? "<error>",
			                 String(describing: serverError))
		}

		DispatchQueue.main.async
		{
			[weak self] in

			guard let self = self else { return }

			self.removeAttachment(upload)
			self.statusComposerController.showAttachmentError(message: errorMessage)
			self.statusComposerController.updateSubmitEnabled()
		}
	}

	public func attachmentUploader(_: AttachmentUploader, updatedDescription _: String?, for upload: Upload)
	{
		DispatchQueue.main.async
		{
			[weak self] in
			self?.uploadsWithDescriptionUpdateError.remove(upload)
			self?.statusComposerController.updateSubmitEnabled()

			if let uploadItem = self?.collectionViewItem(for: upload)
			{
				uploadItem.hasFailure = false
				uploadItem.isPendingSetDescription = false
			}
		}
	}

	public func attachmentUploader(_: AttachmentUploader, failedUpdatingDescriptionFor upload: Upload, previousValue _: String?)
	{
		DispatchQueue.main.async
		{
			[weak self] in
			self?.uploadsWithDescriptionUpdateError.insert(upload)
			self?.statusComposerController.updateSubmitEnabled()

			if let uploadItem = self?.collectionViewItem(for: upload)
			{
				uploadItem.hasFailure = true
				uploadItem.isPendingSetDescription = false
			}
		}
	}
}

public extension AttachmentsSubcontroller
{
	func addAttachments(pasteboard: NSPasteboard) -> Bool
	{
		let types = AttachmentUploader.supportedAttachmentTypes as [String]

		if let fileUrls = pasteboard.readObjects(forClasses: [NSURL.self],
		                                         options: [.urlReadingContentsConformToTypes: types,
		                                                   .urlReadingFileURLsOnly: true]) as? [URL],
			!fileUrls.isEmpty
		{
			addAttachments(fileUrls)
			return true
		}

		// Avoid reading Finder file icons from the pasteboard because that makes no sense
		if pasteboard.types?.contains(.fileURL) == false,
		   let images = pasteboard.readObjects(forClasses: [NSImage.self], options: [:]) as? [NSImage],
		   !images.isEmpty
		{
			addAttachments(images)
			return true
		}

		return false
	}
}
