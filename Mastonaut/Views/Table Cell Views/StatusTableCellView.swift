//
//  StatusTableCellView.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 26.12.18.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2018 Bruno Philipe.
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

import Cocoa
import CoreTootin
import MastodonKit
import Sdifft

@IBDesignable
class StatusTableCellView: MastonautTableCellView, StatusDisplaying, StatusInteractionPresenter
{
	@IBOutlet private unowned var authorNameButton: NSButton!
	@IBOutlet private unowned var authorAccountLabel: NSTextField!
	@IBOutlet unowned var statusLabel: AttributedLabel!
	@IBOutlet private unowned var fullContentDisclosureView: NSView?
	@IBOutlet private unowned var timeLabel: NSTextField!
	@IBOutlet private unowned var editInfoContainer: NSStackView!
	@IBOutlet private unowned var editedTimeLabel: NSTextField!
	@IBOutlet private unowned var mainContentStackView: NSStackView!

	@IBOutlet private unowned var contentWarningContainer: BorderView!
	@IBOutlet private unowned var contentWarningLabel: AttributedLabel!

	@IBOutlet unowned var replyButton: NSButton!
	@IBOutlet unowned var reblogButton: NSButton!
	@IBOutlet unowned var favoriteButton: NSButton!
	@IBOutlet unowned var warningButton: NSButton!
	@IBOutlet unowned var sensitiveContentButton: NSButton!

	@IBOutlet private unowned var contextButton: NSButton?
	@IBOutlet private unowned var contextImageView: NSImageView?

	@IBOutlet private unowned var mediaContainerView: NSView!

	@IBOutlet private unowned var cardContainerView: CardView!
	@IBOutlet private unowned var cardImageView: AttachmentImageView!
	@IBOutlet private unowned var cardTitleLabel: NSTextField!
	@IBOutlet private unowned var cardUrlLabel: NSTextField!

	private var attachmentViewController: AttachmentViewController?

	private var pollViewController: PollViewController?

	private(set) var hasMedia: Bool = false
	private(set) var hasSensitiveMedia: Bool = false
	private(set) var hasSpoiler: Bool = false
	
	private func fontService() -> FontService {
		return FontService(font: MastonautPreferences.instance.statusFont)
	}

	var isContentHidden: Bool
	{
		return warningButton.state == .off
	}

	var isMediaHidden: Bool
	{
		return sensitiveContentButton.state == .off
	}

	private var userDidInteractWithVisibilityControls = false

	private weak var tableViewWidthConstraint: NSLayoutConstraint?

	@objc internal private(set) dynamic
	var cellModel: StatusCellModel?
	{
		didSet { updateAccessibilityAttributes() }
	}

	private lazy var spoilerCoverView: NSView =
	{
		let coverView = CoverView(backgroundColor: NSColor(named: "SpoilerCoverBackground")!,
		                          message: 🔠("Content Hidden: Click warning button below to toggle display."))
		coverView.target = self
		coverView.action = #selector(toggleContentVisibility)
		return coverView
	}()

	// this is exempt from #83 (custom font) for now, because it's mostly UI
	// chrome, not content
	private static let _contextLabelAttributes: [NSAttributedString.Key: AnyObject] = [
		.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 12, weight: .medium)
	]

	internal func authorLabelAttributes() -> [NSAttributedString.Key: AnyObject]
	{
		return fontService().authorAttributes()
	}

	internal func statusLabelAttributes() -> [NSAttributedString.Key: AnyObject]
	{
		return fontService().statusAttributes()
	}

	internal func statusLabelLinkAttributes() -> [NSAttributedString.Key: AnyObject]
	{
		return fontService().statusLinkAttributes()
	}

	internal func contextLabelAttributes() -> [NSAttributedString.Key: AnyObject]
	{
		return StatusTableCellView._contextLabelAttributes
	}

	override func awakeFromNib()
	{
		super.awakeFromNib()

		timeLabel.formatter = RelativeDateFormatter.shared
		statusLabel.linkTextAttributes = statusLabelLinkAttributes()

		cardContainerView.clickHandler = { [weak self] in self?.cellModel?.openCardLink() }

		fontObserver = MastonautPreferences.instance.observe(\.statusFont, options: .new)
		{
			[weak self] _, _ in
			self?.updateFont()
		}
	}

	private var fontObserver: NSKeyValueObservation?

	deinit
	{
		fontObserver?.invalidate()
	}

	func updateFont()
	{
		statusLabel.linkTextAttributes = statusLabelLinkAttributes()

		redraw()
	}

	override var backgroundStyle: NSView.BackgroundStyle
	{
		didSet
		{
			let emphasized = backgroundStyle == .emphasized
			statusLabel.isEmphasized = emphasized
			contentWarningLabel.isEmphasized = emphasized

			let effectiveColor: NSColor = emphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
			cardContainerView.borderColor = effectiveColor

			if #available(OSX 10.14, *) {} else
			{
				authorAccountLabel.textColor = effectiveColor
				timeLabel.textColor = effectiveColor
				cardTitleLabel.textColor = effectiveColor
				cardUrlLabel.textColor = effectiveColor
			}
		}
	}

	func set(displayedStatus status: Status,
	         poll: Poll?,
	         attachmentPresenter: AttachmentPresenting,
	         interactionHandler: StatusInteractionHandling,
	         activeInstance: Instance)
	{
		let cellModel = StatusCellModel(status: status,
		                                poll: poll,
		                                attachmentPresenter: attachmentPresenter,
		                                interactionHandler: interactionHandler,
		                                activeInstance: activeInstance)
		self.cellModel = cellModel

		redraw()
	}

	func redraw()
	{
		guard let cellModel
		else { return }

		let status = cellModel.status

		statusLabel.linkHandler = cellModel
		contentWarningLabel.linkHandler = cellModel

		authorNameButton.set(stringValue: cellModel.visibleStatus.authorName,
							 applyingAttributes: fontService().authorAttributes(),
		                     applyingEmojis: cellModel.visibleStatus.account.cacheableEmojis)

		contextButton.map { cellModel.setupContextButton($0, attributes: contextLabelAttributes()) }

		authorAccountLabel.stringValue = cellModel.visibleStatus.account.uri(in: cellModel.activeInstance)
		timeLabel.objectValue = cellModel.visibleStatus.createdAt
		timeLabel.toolTip = DateFormatter.longDateFormatter.string(from: cellModel.visibleStatus.createdAt)

		if let editedAt = cellModel.visibleStatus.editedAt
		{
			editInfoContainer.isHidden = false
			editedTimeLabel.objectValue = "Edited \(RelativeDateFormatter.shared.string(from: editedAt))"
			editedTimeLabel.toolTip = DateFormatter.longDateFormatter.string(from: editedAt)
		}
		else
		{
			editInfoContainer.isHidden = true
		}

		let attributedStatus = cellModel.visibleStatus.attributedContent

		// We test the attributed string since it might produce a visually empty result if the contents were simply the
		// same link URL as the link on a card, for example.
		if attributedStatus.isEmpty, status.mediaAttachments.isEmpty == false
		{
			statusLabel.stringValue = ""
			statusLabel.toolTip = nil
			statusLabel.isHidden = true
			fullContentDisclosureView?.isHidden = true
		}
		else if fullContentDisclosureView != nil, attributedStatus.length > 500
		{
			let truncatedString = attributedStatus.attributedSubstring(from: NSMakeRange(0, 500)).mutableCopy() as! NSMutableAttributedString
			truncatedString.append(NSAttributedString(string: "…"))

			statusLabel.isHidden = false
			fullContentDisclosureView?.isHidden = false
			statusLabel.set(attributedStringValue: truncatedString,
			                applyingAttributes: statusLabelAttributes(),
			                applyingEmojis: cellModel.visibleStatus.cacheableEmojis)
		}
		else
		{
			statusLabel.isHidden = false
			fullContentDisclosureView?.isHidden = true
			statusLabel.set(attributedStringValue: attributedStatus,
			                applyingAttributes: statusLabelAttributes(),
			                applyingEmojis: cellModel.visibleStatus.cacheableEmojis)
		}

		statusLabel.isEnabled = true

		if cellModel.visibleStatus.spoilerText.isEmpty
		{
			contentWarningContainer.isHidden = true
			warningButton.isHidden = true
			set(displayedCard: cellModel.visibleStatus.card)

			hasSpoiler = false
			contentWarningLabel.stringValue = ""
			contentWarningLabel.toolTip = nil
		}
		else
		{
			cardContainerView.isHidden = true
			warningButton.isHidden = false

			hasSpoiler = true

			contentWarningLabel.set(attributedStringValue: cellModel.visibleStatus.attributedSpoiler,
			                        applyingAttributes: statusLabelAttributes(),
			                        applyingEmojis: cellModel.visibleStatus.cacheableEmojis)

			installSpoilerCover()
			contentWarningContainer.isHidden = false
		}

		setUpInteractions(status: cellModel.visibleStatus)

		setupAttachmentsContainerView(for: cellModel.visibleStatus,
		                              poll: cellModel.poll,
		                              attachmentPresenter: cellModel.attachmentPresenter)
		hasMedia = attachmentViewController != nil
		hasSensitiveMedia = attachmentViewController?.sensitiveMedia == true
	}

	func updateAccessibilityAttributes()
	{
		guard let model = cellModel
		else
		{
			setAccessibilityLabel("")
			return
		}

		var components = [String]()

		components.append(model.visibleStatus.authorName)
		components.append(model.visibleStatus.attributedContent.strippingEmojiAttachments(insertJoinersBetweenEmojis: false))
		components.append(RelativeDateFormatter.shared.string(from: model.visibleStatus.createdAt))
		components.append(model.visibleStatus.authorAccount)

		if model.visibleStatus.id != model.status.id
		{
			let rebloggedAt = RelativeDateFormatter.shared.string(from: model.status.createdAt)
			components.append("retooted by \(model.status.authorName) \(rebloggedAt)")
			components.append(model.status.authorAccount)
		}

		setAccessibilityLabel("Toot")
		setAccessibilityElement(true)
		setAccessibilityTitle(components.joined(separator: ", "))
	}

	func set(updatedPoll: Poll)
	{
		pollViewController?.set(poll: updatedPoll)
	}

	func setHasActivePollTask(_ hasTask: Bool)
	{
		pollViewController?.setHasActiveReloadTask(hasTask)
	}

	func updateContentsVisibility()
	{
		guard userDidInteractWithVisibilityControls == false else { return }

		if hasSpoiler
		{
			switch Preferences.spoilerDisplayMode
			{
			case .alwaysHide:
				setContentHidden(true)
				setMediaHidden(true)

			case .hideMedia:
				setContentHidden(false)
				setMediaHidden(true)

			case .alwaysReveal:
				setContentHidden(false)
				setMediaHidden(false)
			}
		}
		else if hasMedia
		{
			switch Preferences.mediaDisplayMode
			{
			case .alwaysHide:
				setMediaHidden(true)

			case .hideSensitiveMedia:
				setMediaHidden(hasSensitiveMedia)

			case .alwaysReveal:
				setMediaHidden(false)
			}
		}
	}

	private func setupAttachmentsContainerView(for status: Status, poll: Poll?,
	                                           attachmentPresenter: AttachmentPresenting)
	{
		mediaContainerView.subviews.forEach { $0.removeFromSuperview() }

		if status.mediaAttachments.count > 0
		{
			mediaContainerView.isHidden = false

			let attachmentViewController = AttachmentViewController(attachments: status.mediaAttachments,
			                                                        attachmentPresenter: attachmentPresenter,
			                                                        sensitiveMedia: status.sensitive == true,
			                                                        mediaHidden: self.attachmentViewController?.isMediaHidden)

			let attachmentView = attachmentViewController.view
			mediaContainerView.addSubview(attachmentView)

			NSLayoutConstraint.activate([
				mediaContainerView.leftAnchor.constraint(equalTo: attachmentView.leftAnchor),
				mediaContainerView.rightAnchor.constraint(equalTo: attachmentView.rightAnchor),
				mediaContainerView.topAnchor.constraint(equalTo: attachmentView.topAnchor),
				mediaContainerView.bottomAnchor.constraint(equalTo: attachmentView.bottomAnchor)
			])

			self.attachmentViewController = attachmentViewController
		}
		else if let poll = poll ?? status.poll
		{
			mediaContainerView.isHidden = true

			let pollViewController = PollViewController()
			pollViewController.set(poll: poll)
			pollViewController.delegate = cellModel

			let pollView = pollViewController.view
			mainContentStackView.addArrangedSubview(pollView)

			mainContentStackView.widthAnchor.constraint(equalTo: pollView.widthAnchor).isActive = true

			self.pollViewController = pollViewController
		}
		else
		{
			mediaContainerView.isHidden = true
			attachmentViewController = nil
		}
	}

	internal func set(displayedCard card: Card?)
	{
		guard let card = card
		else
		{
			cardContainerView.isHidden = true
			return
		}

		let cardUrl = card.url

		cardContainerView.isHidden = false
		cardTitleLabel.stringValue = card.title
		cardUrlLabel.stringValue = cardUrl.host ?? ""

		guard card.imageUrl != nil, let currentlyDisplayedStatusId = cellModel?.status.id
		else
		{
			cardImageView.image = nil
			return
		}

		cardImageView.image = #imageLiteral(resourceName: "missing")

		card.fetchImage
		{
			[weak self] image in

			DispatchQueue.main.async
			{
				guard self?.cellModel?.status.id == currentlyDisplayedStatusId
				else
				{
					return
				}

				self?.cardImageView.image = image
			}
		}
	}

	func setContentLabelsSelectable(_ selectable: Bool)
	{
		contentWarningLabel.selectableAfterFirstClick = selectable
		statusLabel.selectableAfterFirstClick = selectable
	}

	override func prepareForReuse()
	{
		super.prepareForReuse()

		cellModel = nil
		statusLabel.alphaValue = 1
		userDidInteractWithVisibilityControls = false

		pollViewController?.view.removeFromSuperview()
		pollViewController = nil

		removeSpoilerCover()
	}

	@IBAction func viewHistoryClicked(_ sender: NSButton)
	{
		guard let status = cellModel?.visibleStatus,
		      let interactionHandler = cellModel?.interactionHandler
		else { return }

		let handler = cellModel?.interactionHandler

		interactionHandler.fetchEditHistory(for: status.id)
		{
			success in DispatchQueue.main.async
			{
				guard let edits = success else { return }

				interactionHandler.showStatusEdits(status: status, edits: edits)
			}
		}
	}

	@IBAction private func interactionButtonClicked(_ sender: NSButton)
	{
		switch (sender, sender.state)
		{
		case (favoriteButton, .on):
			cellModel?.handle(interaction: .favorite)

		case (favoriteButton, .off):
			cellModel?.handle(interaction: .unfavorite)

		case (reblogButton, .on):
			cellModel?.handle(interaction: .reblog)

		case (reblogButton, .off):
			cellModel?.handle(interaction: .unreblog)

		case (replyButton, _):
			cellModel?.handle(interaction: .reply)

		case (warningButton, .on):
			userDidInteractWithVisibilityControls = true
			setContentHidden(false)
			setMediaHidden(false)

		case (warningButton, .off):
			userDidInteractWithVisibilityControls = true
			setContentHidden(true)
			setMediaHidden(true)

		case (sensitiveContentButton, .on):
			userDidInteractWithVisibilityControls = true
			setMediaHidden(false)

		case (sensitiveContentButton, .off):
			userDidInteractWithVisibilityControls = true
			setMediaHidden(true)

		default: break
		}
	}

	@objc func toggleContentVisibility()
	{
		guard hasSpoiler else { return }

		setContentHidden(!isContentHidden)
		if isMediaHidden && !isContentHidden
		{
			setMediaHidden(isContentHidden)
		}

		userDidInteractWithVisibilityControls = true
	}

	func toggleMediaVisibility()
	{
		guard hasMedia else { return }

		setMediaHidden(!isMediaHidden)

		userDidInteractWithVisibilityControls = true
	}

	@IBAction func showAuthor(_ sender: Any)
	{
		cellModel?.showAuthor()
	}

	@IBAction func showAgent(_ sender: Any)
	{
		cellModel?.showAgent()
	}

	@IBAction func showTootDetails(_ sender: Any)
	{
		cellModel?.showTootDetails()
	}

	@IBAction func showContextDetails(_ sender: Any)
	{
		cellModel?.showContextDetails()
	}

	func setMediaHidden(_ hideMedia: Bool)
	{
		attachmentViewController?.setMediaHidden(hideMedia)
		sensitiveContentButton.state = hideMedia ? .off : .on
	}

	func setContentHidden(_ hideContent: Bool)
	{
		let coverView = spoilerCoverView
		let hasSensitiveMedia = attachmentViewController?.sensitiveMedia == true

		warningButton.state = hideContent ? .off : .on

		statusLabel.animator().alphaValue = hideContent ? 0 : 1
		statusLabel.setAccessibilityEnabled(!hideContent)
		attachmentViewController?.view.animator().alphaValue = hideContent ? 0 : 1
		attachmentViewController?.view.setAccessibilityEnabled(!hideContent)
		coverView.setHidden(!hideContent, animated: true)
		statusLabel.isEnabled = !hideContent

		if hasSensitiveMedia
		{
			sensitiveContentButton.setHidden(hideContent, animated: true)
		}
	}

	internal func installSpoilerCover()
	{
		removeSpoilerCover()

		let spoilerCover = spoilerCoverView
		addSubview(spoilerCover)

		let spacing = mainContentStackView.spacing

		NSLayoutConstraint.activate([
			spoilerCover.topAnchor.constraint(equalTo: contentWarningContainer.bottomAnchor, constant: spacing),
			spoilerCover.bottomAnchor.constraint(equalTo: mainContentStackView.bottomAnchor, constant: 2),
			spoilerCover.leftAnchor.constraint(equalTo: mainContentStackView.leftAnchor),
			spoilerCover.rightAnchor.constraint(equalTo: mainContentStackView.rightAnchor)
		])
	}

	internal func removeSpoilerCover()
	{
		spoilerCoverView.removeFromSuperview()
	}
}

extension StatusTableCellView: MediaPresenting
{
	func makePresentableMediaVisible()
	{
		attachmentViewController?.presentAttachment(nil)
	}
}

extension StatusTableCellView: RichTextCapable
{
	func set(shouldDisplayAnimatedContents animates: Bool)
	{
		authorNameButton.animatedEmojiImageViews?.forEach { $0.animates = animates }
		contextButton?.animatedEmojiImageViews?.forEach { $0.animates = animates }
		statusLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
		contentWarningLabel.animatedEmojiImageViews?.forEach { $0.animates = animates }
	}
}
