//
//  ProfileTableCellView.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 02.04.19.
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

import Cocoa
import MastodonKit
import CoreTootin

class ProfileTableCellView: MastonautTableCellView
{
	@IBOutlet private unowned var avatarImageView: NSImageView!
	@IBOutlet private unowned var headerImageView: NSImageView!

	@IBOutlet private unowned var userBioLabel: AttributedLabel!

	@IBOutlet private unowned var relationshipButtonsContainer: NSView!
	@IBOutlet private unowned var followButton: NSButton!
	@IBOutlet private unowned var blockButton: NSButton!
	@IBOutlet private unowned var muteButton: NSButton!

	@IBOutlet private unowned var relationshipLabel: NSTextField!

	@IBOutlet private unowned var statusCountLabel: NSTextField!
	@IBOutlet private unowned var followsCountLabel: NSTextField!
	@IBOutlet private unowned var followersCountLabel: NSTextField!

	@IBOutlet private unowned var listSourceSegmentedControl: NSSegmentedControl!

	@IBOutlet private var fieldsController: ProfileFieldsController!

	private static let bioLabelAttributes: [NSAttributedString.Key: AnyObject] = [
		.foregroundColor: NSColor.labelColor, .font: NSFont.labelFont(ofSize: 14),
		.underlineStyle: NSNumber(value: 0) // <-- This is a hack to prevent the label's contents from shifting
											// vertically when clicked.
	]

	private static let bioLabelLinkAttributes: [NSAttributedString.Key: AnyObject] = [
		.foregroundColor: NSColor.safeControlTintColor,
		.font: NSFont.systemFont(ofSize: 14, weight: .medium),
		.underlineStyle: NSNumber(value: 1)
	]

	private static let displayNameAttributes: [NSAttributedString.Key: AnyObject] = [
		.foregroundColor: NSColor.labelColor, .font: NSFont.systemFont(ofSize: 14, weight: .semibold)
	]

	var profileDisplayModeDidChange: ((ProfileViewController.ProfileDisplayMode) -> Void)? = nil
	var relationshipInteractionHandler: ((RelationshipInteraction) -> Void)? = nil

	func setProfileDisplayMode(_ mode: ProfileViewController.ProfileDisplayMode)
	{
		switch mode
		{
		case .statuses: 			listSourceSegmentedControl.setSelected(true, forSegment: 0)
		case .statusesAndReplies:	listSourceSegmentedControl.setSelected(true, forSegment: 1)
		case .mediaOnly:			listSourceSegmentedControl.setSelected(true, forSegment: 2)
		}
	}

	override func awakeFromNib()
	{
		super.awakeFromNib()

		userBioLabel.linkTextAttributes = ProfileTableCellView.bioLabelLinkAttributes
		relationshipButtonsContainer.isHidden = true

		relationshipLabel.isHidden = true
	}

	func clear()
	{
		fieldsController.set(account: nil)
		userBioLabel.stringValue = ""
		userBioLabel.isHidden = true
		statusCountLabel.stringValue = "––"
		followsCountLabel.stringValue = "––"
		followersCountLabel.stringValue = "––"
		relationshipLabel.stringValue = ""
		relationshipLabel.isHidden = true
	}

	func updateAccountControls(with account: Account)
	{
		fieldsController.set(account: account)

		let attributedNote = account.attributedNote

		if attributedNote.isEmpty
		{
			userBioLabel.isHidden = true
		}
		else
		{
			userBioLabel.isHidden = false
			userBioLabel.set(attributedStringValue: attributedNote,
							 applyingAttributes: ProfileTableCellView.bioLabelAttributes,
							 applyingEmojis: account.cacheableEmojis)

			userBioLabel.selectableAfterFirstClick = true
		}

		statusCountLabel.stringValue = "\(account.statusesCount)"
		followsCountLabel.stringValue = "\(account.followingCount)"
		followersCountLabel.stringValue = "\(account.followersCount)"
	}

	func set(linkHandler: AttributedLabelLinkHandler)
	{
		userBioLabel.linkHandler = linkHandler
		fieldsController.set(linkHandler: linkHandler)
	}

	func setRelationship(_ relationship: RelationshipSet)
	{
		if let description = relationship.userDescription, !description.isEmpty
		{
			relationshipLabel.stringValue = description
			relationshipLabel.isHidden = false
		}
		else
		{
			relationshipLabel.stringValue = ""
			relationshipLabel.isHidden = true
		}

		guard !relationship.contains(.isSelf) else {
			relationshipButtonsContainer.setHidden(true, animated: true)
			return
		}

		relationshipButtonsContainer.setHidden(false, animated: true)

		followButton.target = self
		followButton.isEnabled = true
		followButton.title = relationship.contains(.following) ? 🔠("Unfollow") : 🔠("Follow")
		followButton.action = relationship.contains(.following) ? #selector(unfollowAccount(_:))
																: #selector(followAccount(_:))

		blockButton.target = self
		blockButton.isEnabled = true
		blockButton.title = relationship.contains(.blocked) ? 🔠("Unblock") : 🔠("Block")
		blockButton.action = relationship.contains(.blocked) ? #selector(unblockAccount(_:))
															 : #selector(blockAccount(_:))

		muteButton.target = self
		muteButton.isEnabled = true
		muteButton.title = relationship.contains(.muted) ? 🔠("Unmute") : 🔠("Mute")
		muteButton.action = relationship.contains(.muted) ? #selector(unmuteAccount(_:))
														  : #selector(muteAccount(_:))
	}

	func setAvatar(with image: NSImage)
	{
		avatarImageView.image = image
	}

	func setHeader(with image: NSImage?)
	{
		if let image = image
		{
			headerImageView.image = image
		}
		else
		{
			headerImageView.image = #imageLiteral(resourceName: "missing_header")
		}
	}

	@IBAction func profileModeSegmentedControlAction(_ sender: NSSegmentedControl)
	{
		guard let didChangeBlock = self.profileDisplayModeDidChange else { return }

		switch sender.selectedSegment
		{
		case 0: didChangeBlock(.statuses)
		case 1: didChangeBlock(.statusesAndReplies)
		case 2: didChangeBlock(.mediaOnly)
		default: break
		}
	}

	enum RelationshipInteraction
	{
		case follow, unfollow, block, unblock, mute, unmute
	}
}

private extension ProfileTableCellView
{
	@objc func followAccount(_ sender: NSButton?)
	{
		relationshipInteractionHandler?(.follow)
		sender?.isEnabled = false
	}

	@objc func unfollowAccount(_ sender: NSButton?)
	{
		relationshipInteractionHandler?(.unfollow)
		sender?.isEnabled = false
	}

	@objc func blockAccount(_ sender: NSButton?)
	{
		relationshipInteractionHandler?(.block)
		sender?.isEnabled = false
	}

	@objc func unblockAccount(_ sender: NSButton?)
	{
		relationshipInteractionHandler?(.unblock)
		sender?.isEnabled = false
	}

	@objc func muteAccount(_ sender: NSButton?)
	{
		relationshipInteractionHandler?(.mute)
		sender?.isEnabled = false
	}

	@objc func unmuteAccount(_ sender: NSButton?)
	{
		relationshipInteractionHandler?(.unmute)
		sender?.isEnabled = false
	}
}

private extension RelationshipSet
{
	var userDescription: String?
	{
		var sentences: [String] = []

		if contains(.blocked) {
			sentences.append(🔠("relationship.blocked"))
		}
		else if contains([.follower, .following]) {
			sentences.append(🔠("relationship.mutual"))
		}
		else if contains(.follower) {
			sentences.append(🔠("relationship.follower"))
		}
		
		if contains(.followingRequested)
		{
			sentences.append(🔠("relationship.followingRequested"))
		}

		if contains(.muted)
		{
			sentences.append(🔠("relationship.muted"))
		}

		if contains(.isAuthor)
		{
			sentences.append(🔠("relationship.creator"))
		}

		return sentences.filter({!$0.isEmpty}).joined(separator: "\n")
	}
}

extension ProfileTableCellView: RichTextCapable
{
	func set(shouldDisplayAnimatedContents animates: Bool)
	{
		userBioLabel.animatedEmojiImageViews?.forEach({ $0.animates = animates })
	}
}
