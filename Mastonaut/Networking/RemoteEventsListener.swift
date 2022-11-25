//
//  RemoteEventsListener.swift
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

import Foundation
import Starscream
import MastodonKit
import CoreTootin

class RemoteEventsListener: NSObject
{
	private let socketUrl: URL
	private let accessToken: String
	private var lastResolvedURL: URL?

	private var socket: WebSocket? = nil

	private var isReconnecting: Bool = false
	private var reconnectDelay: TimeInterval = 0.5
	private var reconnectTimer: Timer? = nil

	weak var delegate: RemoteEventsListenerDelegate? = nil

	var isSocketConnected: Bool
	{
		return socket?.isConnected == true
	}

	init(baseUrl: URL, accessToken: String, delegate: RemoteEventsListenerDelegate? = nil)
	{
		self.socketUrl = baseUrl.appendingPathComponent("/api/v1/streaming")
		self.accessToken = accessToken
		self.delegate = delegate
		super.init()
	}

	deinit
	{
		socket?.disconnect()

		RemoteEventsListener.cancelPreviousPerformRequests(withTarget: self,
														   selector: #selector(watchdogBarked),
														   object: nil)

		RemoteEventsListener.cancelPreviousPerformRequests(withTarget: self,
														   selector: #selector(releaseWatchdog),
														   object: nil)
	}

	func set(stream: Stream)
	{
		var components = URLComponents(url: socketUrl, resolvingAgainstBaseURL: false)!
		components.queryItems = stream.makeQueryItems(accessToken: accessToken)
		set(resolvedSocketURL: components.url!)
	}

	private func set(resolvedSocketURL: URL)
	{
		let socket = WebSocket(url: resolvedSocketURL)
		socket.delegate = self
		socket.pongDelegate = self

		self.socket?.disconnect(forceTimeout: 0, closeCode: CloseCode.noStatusReceived.rawValue)
		self.socket = socket
		self.lastResolvedURL = resolvedSocketURL

		socket.connect()
	}

	func disconnect()
	{
		socket?.disconnect()
		resetReconnectState()
	}

	/// This method is idempotent.
	func reconnect()
	{
		DispatchQueue.main.async
			{
				self.performReconnect()
				self.debugLog("Reconnect")
			}
	}

	private func performReconnect()
	{
		guard let url = lastResolvedURL, !isReconnecting else
		{
			return
		}

		isReconnecting = true

		DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) {
			self.set(resolvedSocketURL: url)
			self.debugLog("Reconnecting")
		}
	}

	private func resetReconnectState()
	{
		isReconnecting = false
		reconnectDelay = 0.5
	}

	private func resetWatchdog()
	{
		RemoteEventsListener.cancelPreviousPerformRequests(withTarget: self,
														   selector: #selector(watchdogBarked),
														   object: nil)

		RemoteEventsListener.cancelPreviousPerformRequests(withTarget: self,
														   selector: #selector(releaseWatchdog),
														   object: nil)

		perform(#selector(releaseWatchdog), with: nil, afterDelay: 60)
		debugLog("Watchdog was reset")
	}

	@objc
	private func releaseWatchdog()
	{
		RemoteEventsListener.cancelPreviousPerformRequests(withTarget: self,
														   selector: #selector(watchdogBarked),
														   object: nil)

		perform(#selector(watchdogBarked), with: nil, afterDelay: 5)
		socket?.write(ping: Data("ping".utf8))
		debugLog("Watchdog was released!")
	}

	@objc
	private func watchdogBarked()
	{
		socket?.disconnect(forceTimeout: 0, closeCode: CloseCode.noStatusReceived.rawValue)
		debugLog("Watchdog barked!!!")
	}

	private func debugLog(_ message: String)
	{
		#if DEBUG
		NSLog("[SOCKET \(addressAsString(self))] \(message)")
		#endif
	}

	enum Stream: Hashable
	{
		case user
		case `public`
		case publicLocal
		case hashtag(String)
		case hashtagLocal(String)
		case list(FollowedList)
		case direct

		var name: String
		{
			switch self
			{
			case .user:			return "user"
			case .public:		return "public"
			case .publicLocal:	return "public:local"
			case .hashtag:		return "hashtag"
			case .hashtagLocal:	return "hashtag:local"
			case .list:			return "list"
			case .direct:		return "direct"
			}
		}

		func makeQueryItems(accessToken: String) -> [URLQueryItem]
		{
			var items: [URLQueryItem] = [
				URLQueryItem(name: "access_token", value: accessToken),
				URLQueryItem(name: "stream", value: name)
			]

			switch self
			{
			case .hashtag(let tag), .hashtagLocal(let tag):
				items.append(URLQueryItem(name: "tag", value: tag))

			case .list(let list):
				items.append(URLQueryItem(name: "list", value: list.id))

			case .user, .public, .publicLocal, .direct:
				break
			}

			return items
		}
	}
}

protocol RemoteEventsListenerDelegate: AnyObject
{
	func remoteEventsListenerDidConnect(_ remoteEventsListener: RemoteEventsListener)
	func remoteEventsListenerDidDisconnect(_ remoteEventsListener: RemoteEventsListener, error: Error?)
	func remoteEventsListener(_ remoteEventsListener: RemoteEventsListener, didHandleEvent: ClientEvent)
	func remoteEventsListener(_ remoteEventsListener: RemoteEventsListener, parserProducedError: Error)
}

extension RemoteEventsListener: WebSocketDelegate, WebSocketPongDelegate
{
	func websocketDidConnect(socket: WebSocketClient)
	{
		debugLog("WebSocket connected!")
		delegate?.remoteEventsListenerDidConnect(self)

		resetReconnectState()
		resetWatchdog()
	}

	func websocketDidDisconnect(socket: WebSocketClient, error: Error?)
	{
		debugLog("WebSocket disconnected!")

		isReconnecting = false
		reconnectDelay = min(reconnectDelay * 2, 15)

		delegate?.remoteEventsListenerDidDisconnect(self, error: error)
	}

	func websocketDidReceiveMessage(socket: WebSocketClient, text: String)
	{
		parseMastodonEvent(with: Data(text.utf8))
		resetReconnectState()
		resetWatchdog()
	}

	func websocketDidReceiveData(socket: WebSocketClient, data: Data)
	{
		parseMastodonEvent(with: data)
		resetReconnectState()
		resetWatchdog()
	}

	func websocketDidReceivePong(socket: WebSocketClient, data: Data?)
	{
		resetWatchdog()
	}

	private func parseMastodonEvent(with data: Data)
	{
		guard data.isEmpty == false else
		{
			// This is a heartbeat message. Ignoring it…
			return
		}

		do
		{
			let payload = try JSONDecoder().decode(StreamPayload.self, from: data)
			delegate?.remoteEventsListener(self, didHandleEvent: try payload.parsedEvent())
		}
		catch
		{
			delegate?.remoteEventsListener(self, parserProducedError: error)
		}
	}
}

private struct StreamPayload: Decodable
{
	let event: String
	let payload: String?

	func parsedEvent() throws -> ClientEvent
	{
		guard let type = EventType(rawValue: event) else
		{
			throw ParseErrors.unknownEventType(event)
		}

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .formatted(DateFormatter.mastodonFormatter)

		switch (type, payload)
		{
		case (.update, .some(let payload)):
			return .update(try decoder.decode(Status.self, from: Data(payload.utf8)))

		case (.notification, .some(let payload)):
			return .notification(try decoder.decode(MastodonKit.Notification.self, from: Data(payload.utf8)))

		case (.delete, .some(let payload)):
			return .delete(statusID: payload)

		case (.filtersChanged, _):
			return .keywordFiltersChanged

		default:
			throw ParseErrors.missingPayload
		}
	}

	enum EventType: String
	{
		case update = "update"
		case notification = "notification"
		case delete = "delete"
		case filtersChanged = "filters_changed"
	}

	enum ParseErrors: Error
	{
		case unknownEventType(String)
		case missingPayload
	}
}

enum ClientEvent
{
	case update(Status)
	case notification(MastodonKit.Notification)
	case delete(statusID: String)
	case keywordFiltersChanged
}

