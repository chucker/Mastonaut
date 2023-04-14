//
//  MastodonAPIMarkerSyncProvider.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 14.04.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation
import MastodonKit

public class MastodonAPIMarkerSyncProvider: MarkerSyncProvider {
	public func read(client: ClientType) async -> Marker? {
		guard let result = try? await client.run(Markers.all(timelines: [.home])),
		      let homeMarker = result.value.home
		else {
			return nil
		}

		return homeMarker
	}

	func write(client: MastodonKit.ClientType, newMarker: MastodonKit.Marker) {
		let markers = MarkerCollection(home: newMarker)

		client.run(Markers.update(markers: markers))
		{
			_ in
		}
	}
}
