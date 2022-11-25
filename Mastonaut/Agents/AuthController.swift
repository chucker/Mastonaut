//
//  AuthController.swift
//  Mastonaut
//
//  Created by Bruno Philipe on 29.12.18.
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
import MastodonKit
import CoreTootin

protocol AuthControllerDelegate: AnyObject
{
	func authControllerDidCancelAuthorization(_ authController: AuthController)
	func authController(_ authController: AuthController, didAuthorize account: Account, uuid: UUID)
	func authController(_ authController: AuthController, failedAuthorizingWithError: AuthController.Errors)

	func authController(_ authController: AuthController, didUpdate account: Account, uuid: UUID)

	func authControllerDidUpdateAllAccountLocalInfo(_ authController: AuthController)
	func authControllerDidUpdateAllAccountRelationships(_ authController: AuthController)
}

class AuthController
{
	private unowned let accountsService = AppDelegate.shared.accountsService

	private let keychainController: KeychainController
	private var authorizationState: AuthorizationState = .initial

	private lazy var registrationAgent = AppRegistrationAgent(keychainController: keychainController)

	weak var delegate: AuthControllerDelegate? = nil

	static let blockedDomains: Set<String> = [
		"gab.ai", "gab.com", "exited.eu", "not-develop.gab.com", "develop.gab.com", "ekrem.develop.gab.com", "gab.io",
		"gabble.xyz", "gab.polaris-1.work", "gabfed.com", "spinster.xyz", "djitter.com", "kazvam.com"
	]

	init(keychainController: KeychainController, delegate: AuthControllerDelegate? = nil)
	{
		self.keychainController = keychainController
		self.delegate = delegate
	}

	func newAuthorization(with sourceWindow: NSWindow)
	{
		cleanupAuthorizationState()

		let pickerWindowController = InstancePickerWindowController()

		guard let window = pickerWindowController.window else
		{
			return
		}

		pickerWindowController.delegate = self

		authorizationState = .pickingDomain(sourceWindow: sourceWindow, sheetWindowController: pickerWindowController)

		sourceWindow.beginSheet(window)
		{
			[weak self, weak delegate] response in

			if let self = self, response == .cancel
			{
				self.cleanupAuthorizationState()

				DispatchQueue.main.async
				{
					delegate?.authControllerDidCancelAuthorization(self)
				}
			}
		}
	}

	func refreshAuthorization(for account: AuthorizedAccount, with sourceWindow: NSWindow)
	{
		let baseDomain = account.baseDomain!

		registrationAgent.clientAppRegistration(for: baseDomain)
			{
				[weak self] result in

				switch result
				{
				case .success(let clientApplication):
					self?.showOAuthWindow(with: baseDomain,
										  clientApplication: clientApplication,
										  sourceWindow: sourceWindow,
										  existingAccount: account)

				case .failure(let error):
					if let self = self
					{
						let restError = Errors.restError(error.localizedDescription)
						self.delegate?.authController(self, failedAuthorizingWithError: restError)
					}
				}
			}
	}

	func completeAuthorization(from domainName: String, grantCode: String)
	{
		guard Thread.isMainThread else
		{
			NSLog("Must be called from main thread!")
			abort()
		}

		switch authorizationState
		{
		case .authorizing(let sourceWindow, let sheetController, let clientApplication, let baseDomain, let account):

			guard baseDomain.hasPrefix(domainName), grantCode.count > 0 else
			{
				attemptToAuthorizeFailedTokenGrant(from: domainName, grantCode: grantCode)
				return
			}

			guard let sheetWindow = sheetController.window,
				sheetWindow.isSheet, sheetWindow.sheetParent === sourceWindow else
			{
				attemptToAuthorizeFailedTokenGrant(from: domainName, grantCode: grantCode)
				return
			}

			performOAuthLogin(baseDomain: baseDomain,
							  grantCode: grantCode,
							  clientApplication: clientApplication,
							  existingAccount: account)
				{
					sourceWindow.endSheet(sheetWindow, returnCode: .continue)
				}

		default:
			attemptToAuthorizeFailedTokenGrant(from: domainName, grantCode: grantCode)
		}
	}

	func removeAllAuthorizationArtifacts()
	{
		try? keychainController.deleteAllStorablesForService()
	}

	func updateAllAccountsLocalInfo()
	{
		#if MOCK
		delegate?.authControllerDidUpdateAllAccountLocalInfo(self)
		#else

		let dispatchGroup = DispatchGroup()

		for account in accountsService.authorizedAccounts
		{
			dispatchGroup.enter()
			updateLocalInfo(for: account) { dispatchGroup.leave() }
		}

		dispatchGroup.notify(queue: .main)
			{
				[weak self] in

				guard let self = self else { return }

				self.delegate?.authControllerDidUpdateAllAccountLocalInfo(self)
			}
		#endif
	}

	private func updateLocalInfo(for authorizedAccount: AuthorizedAccount, completion: @escaping () -> Void)
	{
		guard let client = Client.create(for: authorizedAccount) else
		{
			completion()
			return
		}

		accountsService.details(for: authorizedAccount)
		{
			[weak self] in

			guard case .success(let details) = $0, let self = self else
			{
				completion()
				return
			}

			authorizedAccount.updateLocalInfo(using: details.account, instance: details.instance)
			self.delegate?.authController(self, didUpdate: details.account, uuid: authorizedAccount.uuid)
			self.updateLists(for: authorizedAccount, using: client)
			self.updateBlocksAndMutes(for: details.account,
									 authorizedAccount: authorizedAccount,
									 using: client,
									 completion: completion)
		}
	}

	private func deleteUnreferencedAccountReferences()
	{
		let container = AppDelegate.shared.persistentContainer
		let context = container.viewContext

		guard
			let fetchRequest = container.managedObjectModel.fetchRequestTemplate(forName: "UnreferencedAccounts")
		else { return }

		do
		{
			try context.fetch(fetchRequest as! NSFetchRequest<AccountReference>).forEach({ context.delete($0) })
		}
		catch
		{
			print("Failed fetching account references: \(error)")
		}
	}

	private func updateLists(for authorizedAccount: AuthorizedAccount,
							 using client: ClientType)
	{
		let service = FollowedListsService(client: client, authorizedAccount: authorizedAccount)
		
		service.loadFollowedLists(completion: {
			result in
			
			DispatchQueue.main.async
			{
				if case .success(let allLists) = result
				{
					do { try authorizedAccount.setLists(allLists) }
					catch { print("Could not update lists: \(error)") }
				}
			}
		})
	}
	
	private func updateBlocksAndMutes(for account: Account,
									  authorizedAccount: AuthorizedAccount,
									  using client: ClientType,
									  completion: @escaping () -> Void)
	{
		let service = RelationshipsService(client: client, authorizedAccount: authorizedAccount)
		let dispatchGroup = DispatchGroup()

		dispatchGroup.enter()
		service.loadBlockedAccounts()
			{
				result in

				DispatchQueue.main.async
				{
					if case .success(let allBlockedAccounts) = result
					{
						do { try authorizedAccount.setBlockedAccounts(allBlockedAccounts) }
						catch { print("Could not update blocked accounts: \(error)") }
					}

					dispatchGroup.leave()
				}
			}

		dispatchGroup.enter()
		service.loadMutedAccounts()
		{
			result in

			DispatchQueue.main.async
				{
					if case .success(let allMutedAccounts) = result
					{
						do { try authorizedAccount.setMutedAccounts(allMutedAccounts) }
						catch { print("Could not update muted accounts: \(error)") }
					}

					dispatchGroup.leave()
				}
		}

		dispatchGroup.notify(queue: .main)
			{
				[weak self] in
				guard let self = self else { return }

				self.deleteUnreferencedAccountReferences()
				completion()
			}
	}

	private func attemptToAuthorizeFailedTokenGrant(from domainName: String, grantCode: String)
	{
		registrationAgent.clientAppRegistration(for: domainName)
			{
				[weak self] result in

				DispatchQueue.main.async
				{
					switch result
					{
					case .success(let clientApplication):
						self?.performOAuthLogin(baseDomain: domainName,
												grantCode: grantCode,
												clientApplication: clientApplication,
												existingAccount: nil)

					case .failure(let error):
						if let self = self
						{
							let restError = Errors.restError(error.localizedDescription)
							self.delegate?.authController(self, failedAuthorizingWithError: restError)
						}
					}
				}
		}
	}

	private func performOAuthLogin(baseDomain: String,
								   grantCode: String,
								   clientApplication: ClientApplication,
								   existingAccount: AuthorizedAccount?,
								   completion: (() -> Void)? = nil)
	{
		let client = Client(baseURL: "https://" + baseDomain)
		let context = AppDelegate.shared.managedObjectContext

		client.run(Login.oauth(clientID: clientApplication.clientID,
							   clientSecret: clientApplication.clientSecret,
							   scopes: [.read, .write, .push, .follow],
							   redirectURI: clientApplication.redirectURI,
							   code: grantCode))
		{
			[weak delegate, weak keychainController, weak self, unowned accountsService] loginResult in

			let login: LoginSettings

			switch loginResult
			{
			case .success(let loginResult, _):
				login = loginResult

			case .failure(let error):
				#if DEBUG
				NSLog("Login error: \(error)")
				#endif
				let description = 🔠("Failed authorization from “%@”: Could not log in.", baseDomain)

				DispatchQueue.main.async { completion?() }
				guard let self = self else { return }
				delegate?.authController(self, failedAuthorizingWithError: Errors.restError(description))
				return
			}

			client.accessToken = login.accessToken

			client.fetchAccountAndInstance()
			{
				result in

				guard let keychainController = keychainController else { return }

				let account: Account
				let instance: Instance

				switch result
				{
				case .failure(let error):
					#if DEBUG
					NSLog("Error fetching account info: \(error)")
					#endif
					let description = 🔠("Failed authorization from “%@”: Could not fetch user.", baseDomain)

					DispatchQueue.main.async
					{
						completion?()
						guard let self = self else { return }
						delegate?.authController(self, failedAuthorizingWithError: Errors.restError(description))
					}

					return
				case .success(let result):
					account = result.0
					instance = result.1
				}

				do
				{
					let accountIdentifier = "\(account.username)@\(instance.uri)"

					// The access token goes into the keychain
					let accountAccessToken = AccountAccessToken(account: accountIdentifier,
																accessToken: login.accessToken,
																clientApplication: clientApplication,
																grantCode: grantCode)

					try keychainController.store(accountAccessToken, overwite: true)

					DispatchQueue.main.async
						{
							guard let self = self else
							{
								completion?()
								return
							}

							// The user account info goes into Core Data
							let authorizedAccount: AuthorizedAccount

							if let existingAccount = existingAccount
							{
								authorizedAccount = existingAccount
								authorizedAccount.account = accountIdentifier
								authorizedAccount.baseDomain = baseDomain
								authorizedAccount.accessTokenType = login.accessTokenType
								authorizedAccount.displayName = account.displayName
								authorizedAccount.username = account.username
								authorizedAccount.avatarURL = account.avatarURL
								authorizedAccount.uri = account.uri(in: instance)
								authorizedAccount.needsAuthorization = false
							}
							else
							{
								authorizedAccount = AuthorizedAccount.insert(context: context,
																			 account: accountIdentifier,
																			 baseDomain: baseDomain,
																			 displayName: account.displayName,
																			 username: account.username,
																			 avatarURL: account.avatarURL,
																			 uri: account.uri(in: instance),
																			 login: login)

								accountsService.order.appendAccount(authorizedAccount)
							}

							self.updateBlocksAndMutes(for: account, authorizedAccount: authorizedAccount, using: client)
							{
								[weak self] in

								completion?()
								guard let self = self else { return }
								delegate?.authController(self, didAuthorize: account, uuid: authorizedAccount.uuid)
							}
						}
				}
				catch
				{
					DispatchQueue.main.async { completion?() }
					guard let self = self else { return }
					delegate?.authController(self, failedAuthorizingWithError: Errors.keychainError(error))
				}
			}
		}
	}

	private func showError<T: UserDescriptionError>(_ error: T, with baseDomain: String)
	{
		guard case .pickingDomain(let sourceWindow, _) = authorizationState else
		{
			return
		}

		let alert = NSAlert(style: .warning,
							title: 🔠("Error"),
							message: 🔠("authorization.clientRegistration", baseDomain, error.userDescription))

		alert.addButton(withTitle: 🔠("OK"))

		alert.beginSheetModal(for: sourceWindow) { _ in }
	}

	private func showOAuthWindow(with baseDomain: String,
								 clientApplication: ClientApplication,
								 sourceWindow: NSWindow,
								 existingAccount: AuthorizedAccount?)
	{
		var authUrlPath = "https://" + baseDomain

		if !authUrlPath.hasSuffix("/")
		{
			authUrlPath.append("/")
		}

		authUrlPath.append(clientApplication.authorizationPath)

		let authWindowController = AuthWindowController()

		guard
			let authWindow = authWindowController.window,
			let authUrl = URL(string: authUrlPath)
		else
		{
			delegate?.authController(self, failedAuthorizingWithError: .unknownAuthorization)
			cleanupAuthorizationState()
			return
		}

		authorizationState = .authorizing(sourceWindow: sourceWindow,
										  sheetWindowController: authWindowController,
										  clientApplication: clientApplication,
										  baseDomain: baseDomain,
										  existingAccount: existingAccount)

		authWindowController.loadUrl(authUrl)

		sourceWindow.beginSheet(authWindow)
		{
			[weak self] (response) in

			guard response != .continue, let self = self else { return }

			self.delegate?.authControllerDidCancelAuthorization(self)
			self.cleanupAuthorizationState()
		}
	}

	private func cleanupAuthorizationState()
	{
		switch authorizationState
		{
		case .authorizing(_, let sheetWindowController, _, _, _), .pickingDomain(_, let sheetWindowController):
			if let window = sheetWindowController.window, window.isSheet
			{
				window.sheetParent?.endSheet(window)
			}

		default:
			break
		}

		authorizationState = .initial
	}

	enum Errors: Error
	{
		case restError(String)
		case keychainError(Error)
		case unknownAuthorization

		var localizedDescription: String
		{
			switch self
			{
			case .restError(let error): return "REST: \(error)"
			case .keychainError(let error): return "Keychain: \(error.localizedDescription)"
			case .unknownAuthorization: return 🔠("authorization.unknown")
			}
		}
	}

	enum AuthorizationState
	{
		case initial
		case pickingDomain(sourceWindow: NSWindow, sheetWindowController: NSWindowController)
		case authorizing(sourceWindow: NSWindow, sheetWindowController: NSWindowController, clientApplication: ClientApplication, baseDomain: String, existingAccount: AuthorizedAccount?)
	}
}

extension AuthController: InstancePickerWindowControllerDelegate
{
	func authWindow(_ window: NSWindow, didPickValidBaseDomain baseDomain: String)
	{
		guard case .pickingDomain(let sourceWindow, _) = authorizationState else { return }

		registrationAgent.clientAppRegistration(for: baseDomain)
			{
				[weak self] result in

				DispatchQueue.main.async
					{
						switch result
						{
						case .success(let clientApplication):
							self?.showOAuthWindow(with: baseDomain,
												  clientApplication: clientApplication,
												  sourceWindow: sourceWindow,
												  existingAccount: nil)
						case .failure(let error):
							self?.showError(ValidInstanceCheckErrors.clientError(error), with: baseDomain)
						}
					}
			}
	}
}

private extension ClientApplication
{
	var authorizationPath: String
	{
		return "oauth/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&scope=read+write+push+follow"
	}
}

extension AuthController // Helpers
{
	func checkValidInstanceDomain(_ domain: String,
								  completion: @escaping (Swift.Result<ValidInstance, ValidInstanceCheckErrors>) -> Void)
	{
		let trimmedDomain = domain.trimmingCharacters(in: CharacterSet(charactersIn: "@"))

		guard
			!trimmedDomain.isEmpty,
			let wellFormedUrl = URL(string: "https://\(trimmedDomain)/api/v1/instance"),
			let host = wellFormedUrl.host
		else
		{
			return completion(.failure(.badDomain))
		}

		guard AuthController.blockedDomains.contains(host) == false else
		{
			return completion(.failure(.badDomain))
		}
		
		let client = Client(baseURL: "https://\(host)")

		client.run(Instances.current())
			{
				result in

				switch result
				{
				case .success(let instance, _):
					let validInstance = ValidInstance(baseURL: wellFormedUrl, instance: instance)
					DispatchQueue.main.async { completion(.success(validInstance)) }

				case .failure(let error):
					if case .unauthorized = error {
						DispatchQueue.main.async { completion(.success(ValidInstance(baseURL: wellFormedUrl, instance: nil))) }
					} else {
						DispatchQueue.main.async { completion(.failure(.clientError(error))) }
					}
				}
			}
	}

	struct ValidInstance
	{
		let baseURL: URL
		let instance: Instance?
	}

	enum ValidInstanceCheckErrors: UserDescriptionError
	{
		case badDomain
		case clientError(Error)

		var userDescription: String
		{
			switch self
			{
			case .badDomain: return 🔠("instance.badDomain")
			case .clientError(let error): return 🔠("instance.clientError", error.localizedDescription)
			}
		}
	}
}
