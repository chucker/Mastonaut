//
//  ProfileViewController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 27.03.19.
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

class ProfileViewController: TimelineViewController, SidebarPresentable, AccountBound
{
	private lazy var resourcesFetcher = ResourcesFetcher(urlSession: AppDelegate.shared.resourcesUrlSession)

	private let accountURI: String

	private var pinnedStatusMap: [String: Status] = [:]
	private var pinnedStatusList: [String] = []

	private var displayMode: ProfileDisplayMode = .statuses
	{
		didSet { account.map { source = displayMode.listSource(for: $0.id) } }
	}

	internal var account: Account? = nil
	{
		didSet { account.map { prepareToDisplay(account: $0) } }
	}

	private var accountAvatarImage: NSImage? = nil
	{
		didSet { updateAvatarImage() }
	}

	private var accountHeaderImage: NSImage? = nil
	{
		didSet { updateHeaderImage() }
	}

	var sidebarModelValue: SidebarModel
	{
		return SidebarMode.profile(uri: accountURI)
	}

	var titleMode: SidebarTitleMode
	{
		if let account = self.account
		{
			let font = SidebarTitleViewController.titleAttributes[.font] as? NSFont
			let emojiTitle = NSAttributedString(string: account.bestDisplayName)
							.applyingEmojiAttachments(account.cacheableEmojis, font: font)

			return .subtitle(title: emojiTitle, subtitle: NSAttributedString(string: accountURI))
		}
		else
		{
			return .title(accountURI)
		}
	}

	init(account: Account, instance: Instance)
	{
		self.accountURI = account.uri(in: instance)
		self.account = account

		super.init(source: displayMode.listSource(for: account.id))
	}

	init(uri: String, currentAccount: AuthorizedAccount?, client: ClientType)
	{
		self.accountURI = uri

		super.init(source: nil)

		clearProfileView()

		if currentAccount?.uri == uri
		{
			client.run(Accounts.currentUser())
			{
				[weak self, client] result in

				DispatchQueue.main.async
					{
						guard case .success(let account, _) = result else {
							self?.setProfileNotFound()
							return
						}

						self?.setRecreatedAccount(account)
						self?.client = client
					}
			}
		}
		else
		{
			client.run(Accounts.search(query: uri, limit: 1, resolve: true))
			{
				[weak self, client] result in

				DispatchQueue.main.async
					{
						guard case .success(let accounts, _) = result, let account = accounts.first else {
							self?.setProfileNotFound()
							return
						}

						self?.setRecreatedAccount(account)
						self?.client = client
					}
			}
		}
	}

	required init?(coder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		needsLoadingIndicator = true
		
		topConstraint.constant = -1
		view.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true
		updateAccessibilityAttributes()
	}

	internal func setRecreatedAccount(_ account: Account)
	{
		self.account = account
		self.source = displayMode.listSource(for: account.id)
	}

	override func clientDidChange(_ client: ClientType?, oldClient: ClientType?)
	{
		super.clientDidChange(client, oldClient: oldClient)

		guard let account = self.account else { return }

		prepareToDisplay(account: account)
		fetchPinnedStatuses()
	}

	override func sourceDidChange(source: TimelineViewController.Source?)
	{
		needsLoadingIndicator = true
		
		reloadList()

		if case .some(.userStatuses) = source
		{
			fetchPinnedStatuses()
		}
	}

	private func fetchPinnedStatuses()
	{
		guard let client = self.client, let accountID = self.account?.id else { return }

		client.run(Accounts.statuses(id: accountID, pinnedOnly: true))
			{
				[weak self] result in

				if case .success(let statuses, _) = result
				{
					DispatchQueue.main.async
						{
							self?.prepareNewPinnedStatuses(statuses)
						}
				}
			}
	}

	override func installLoadingIndicator()
	{
		let containerView = tableView.enclosingScrollView?.contentView ?? view
		let indicator = loadingIndicator
		containerView.addSubview(indicator)
		indicator.startAnimation(nil)

		let bottomDistance: CGFloat

		if !entryList.isEmpty, let profileCell = profileCellView()
		{
			bottomDistance = (view.frame.height - profileCell.frame.height) / 2
		}
		else
		{
			bottomDistance = view.frame.height / 2
		}

		NSLayoutConstraint.activate([
			containerView.centerXAnchor.constraint(equalTo: indicator.centerXAnchor),
			containerView.bottomAnchor.constraint(equalTo: indicator.centerYAnchor, constant: bottomDistance)
		])
	}

	override func prepareNewEntries(_ entries: [Status],
									for insertion: ListViewController<Status>.InsertionPoint,
									pagination: Pagination?)
	{
		let (pinnedEntries, filteredEntries) = entries.segregated(using: { $0.pinned == true })

		prepareNewPinnedStatuses(pinnedEntries)
		super.prepareNewEntries(filteredEntries, for: insertion, pagination: pagination)
	}

	private func prepareNewPinnedStatuses(_ statuses: [Status])
	{
		let filteredStatuses = statuses.filter({ pinnedStatusMap[$0.id] == nil })
		handleNewPinnedStatuses(filteredStatuses)
		
		needsLoadingIndicator = false
	}

	private func handleNewPinnedStatuses(_ statuses: [Status])
	{
		guard !statuses.isEmpty else { return }

		for status in statuses {
			status.markAsPinned()
			pinnedStatusMap[status.id] = status
		}

		let newStatusList = pinnedStatusMap.values.sorted(by: { $0.createdAt > $1.createdAt }).map({ $0.id })
		let oldStatusIDSet = Set(pinnedStatusList)
		let newPinnedStatuses = newStatusList.enumerated().filter({ !oldStatusIDSet.contains($0.1) })
		var entryReferences: [Int: EntryReference] = [:]
		let profileCellOffset = entryList.firstIndex(where: { $0.specialKey == "profile" }).map({ $0 + 1 })
								?? entryList.startIndex

		for (index, newStatusID) in newPinnedStatuses
		{
			entryReferences[index + profileCellOffset] = .special(key: "pinned:\(newStatusID)")
		}

		pinnedStatusList = newStatusList
		insert(entryReferences: entryReferences)
	}

	override internal func cleanupSpecialRows(_ entryList: inout [EntryReference])
	{
		pinnedStatusList.removeAll()
		pinnedStatusMap.removeAll()
		entryList.removeAll(where: { $0.specialKey?.hasPrefix("pinned:") == true })
	}

	private func clearProfileView()
	{
		accountAvatarImage = nil
		accountHeaderImage = nil
		updateAccountControls()
	}

	private func setProfileNotFound()
	{
		accountAvatarImage = nil
		accountHeaderImage = nil
		updateAccountControls()
	}

	private func prepareToDisplay(account: Account)
	{
		updateAccessibilityAttributes()

		let completion: () -> Void =
			{
				[weak self] in

				self?.updateProfileCellView()
				self?.invalidateSidebarTitleMode()
			}

		guard !account.emojis.isEmpty else
		{
			completion()
			return
		}

		AppDelegate.shared.customEmojiCache.cacheEmojis(for: [account])
		{
			_ in DispatchQueue.main.async(execute: completion)
		}
	}

	override func prepareToDisplay(cellView: NSTableCellView, at row: Int)
	{
		super.prepareToDisplay(cellView: cellView, at: row)

		if cellView is ProfileTableCellView
		{
			DispatchQueue.main.async
			{
				[weak self] in self?.updateProfileCellView()
			}
		}
	}

	private func updateProfileCellView()
	{
		updateAccountControls()
		updateAvatarImage()
		updateHeaderImage()
	}

	override func insertSpecialRows()
	{
		super.insertSpecialRows()
		insert(entryReferences: [0: .special(key: "profile")])
	}

	override func registerCells()
	{
		super.registerCells()

		tableView.register(NSNib(nibNamed: "ProfileTableCellView", bundle: .main), forIdentifier: CellViewIdentifier.profile)
	}

	override func cellIdentifier(for specialCellKey: String) -> NSUserInterfaceItemIdentifier
	{
		if specialCellKey.hasPrefix("pinned:")
		{
			return StatusListViewController.CellViewIdentifier.status
		}
		else
		{
			return CellViewIdentifier.profile
		}
	}

	override func populate(specialCell: NSTableCellView, for specialCellKey: String)
	{
		if specialCellKey.hasPrefix("pinned:"),
			let status = pinnedStatusMap[specialCellKey.substring(afterPrefix: "pinned:")]
		{
			populate(cell: specialCell, for: status)
		}
	}

	override func menuItems(for entryReference: EntryReference) -> [NSMenuItem]
	{
		if case .special(let specialCellKey) = entryReference, let account = self.account
		{
			if specialCellKey.hasPrefix("pinned:"),
				let status = pinnedStatusMap[specialCellKey.substring(afterPrefix: "pinned:")]
			{
				return StatusMenuItemsController.shared.menuItems(for: status, interactionHandler: self)
			}
			else if specialCellKey == "profile"
			{
				return AccountMenuItemsController.shared.menuItems(for: account, interactionHandler: self)
			}
		}

		return super.menuItems(for: entryReference)
	}

	override func handle(updatedStatus: Status)
	{
		if updatedStatus.pinned == true && pinnedStatusMap[updatedStatus.id] == nil
		{
			handleNewPinnedStatuses([updatedStatus])
			// remove old status, maybe?
		}
		else if let statusID = pinnedStatusMap.removeValue(forKey: updatedStatus.id)?.id
		{
			pinnedStatusList.firstIndex(of: statusID).map { _ = pinnedStatusList.remove(at: $0) }
			handle(deletedEntry: .special(key: "pinned:\(statusID)"))
		}
	}

	private func profileCellView() -> ProfileTableCellView?
	{
		guard numberOfRows(in: tableView) > 0 else { return nil }
		return tableView.view(atColumn: 0, row: 0, makeIfNecessary: false) as? ProfileTableCellView
	}

	private func updateAccountControls()
	{
		guard !entryList.isEmpty, let profileCellView = profileCellView() else { return }

		guard let account = self.account else
		{
			profileCellView.clear()
			return
		}

		profileCellView.updateAccountControls(with: account)
		profileCellView.setProfileDisplayMode(displayMode)
		profileCellView.profileDisplayModeDidChange = { [unowned self] in self.displayMode = $0 }

		if let linkHandler = authorizedAccountProvider
		{
			profileCellView.set(linkHandler: linkHandler)
		}

		guard
			let authorizedAccount = authorizedAccountProvider?.currentAccount,
			let client = self.client
		else { return }

		let relationshipService = RelationshipsService(client: client, authorizedAccount: authorizedAccount)

		relationshipService.relationship(with: account) { profileCellView.setRelationship($0) }
		profileCellView.relationshipInteractionHandler =
			{
				[unowned self] interaction in

				self.process(relationshipInteraction: interaction, relationshipService: relationshipService)
			}
	}

	private func process(relationshipInteraction: ProfileTableCellView.RelationshipInteraction,
						 relationshipService service: RelationshipsService)
	{
		guard let account = self.account else { return }

		let completion: (Swift.Result<AccountReference, RelationshipsService.Errors>) -> Void =
			{
				[weak self, account] result in

				guard let profileCellView = self?.profileCellView() else { return }

				guard case .success(let reference) = result else {
					service.relationship(with: account) { profileCellView.setRelationship($0) }
					return
				}

				profileCellView.setRelationship(reference.relationshipSet(with: account, isSelf: false))
			}

		switch relationshipInteraction
		{
		case .follow:	service.follow(account: account, completion: completion)
		case .unfollow:	service.unfollow(account: account, completion: completion)
		case .block:	service.block(account: account, completion: completion)
		case .unblock:	service.unblock(account: account, completion: completion)
		case .mute:		service.mute(account: account, completion: completion)
		case .unmute:	service.unmute(account: account, completion: completion)
		}
	}

	private func updateAvatarImage()
	{
		guard let account = self.account, let profileCellView = profileCellView() else { return }

		if let avatarImage = accountAvatarImage {
			profileCellView.setAvatar(with: avatarImage)
		} else if let avatarURL = account.avatarURL {
			fetchImageOrFallback(url: avatarURL) { [weak self] image in
				DispatchQueue.main.async {
					self?.accountAvatarImage = image
				}
			}
		} else {
			profileCellView.setAvatar(with: #imageLiteral(resourceName: "missing"))
		}
	}

	private func updateHeaderImage()
	{
		guard let account = self.account, let profileCellView = profileCellView() else { return }

		if let headerImage = accountHeaderImage {
			profileCellView.setHeader(with: headerImage)
		} else if let headerURL = account.headerURL, !headerURL.lastPathComponent.contains("missing.") {
			fetchImageOrFallback(url: headerURL) { [weak self] image in
				DispatchQueue.main.async {
					self?.accountHeaderImage = image
				}
			}
		} else {
			profileCellView.setHeader(with: nil)
		}
	}

	private func fetchImageOrFallback(url: URL, completion: @escaping (NSImage) -> Void)
	{
		resourcesFetcher.fetchImage(with: url) { (result) in
			if case .success(let image) = result
			{
				completion(image)
			}
			else
			{
				completion(#imageLiteral(resourceName: "missing"))
			}
		}
	}

	private func updateAccessibilityAttributes() {
		guard isViewLoaded, let source = source, let account = account else {
			tableView?.setAccessibilityLabel(nil)
			return
		}

		switch source {
		case .userStatuses:
			tableView.setAccessibilityLabel("\(account.bestDisplayName) Profile")
		case .userStatusesAndReplies:
			tableView.setAccessibilityLabel("\(account.bestDisplayName) Profile with Replies")
		case .userMediaStatuses:
			tableView.setAccessibilityLabel("\(account.bestDisplayName) Profile with Media")
		default:
			break
		}
	}

	enum ProfileDisplayMode
	{
		case statuses
		case statusesAndReplies
		case mediaOnly

		func listSource(for accountId: String) -> TimelineViewController.Source
		{
			switch self
			{
			case .statuses: return .userStatuses(id: accountId)
			case .statusesAndReplies: return .userStatusesAndReplies(id: accountId)
			case .mediaOnly: return .userMediaStatuses(id: accountId)
			}
		}
	}

	private struct CellViewIdentifier
	{
		static let profile = NSUserInterfaceItemIdentifier("profile")
	}
}
