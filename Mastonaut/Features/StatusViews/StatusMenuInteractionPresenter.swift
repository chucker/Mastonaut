//
//  StatusMenuInteractionPresenter.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 07.06.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

protocol StatusMenuInteractionValidating: MastonautTableCellView {
	var statusModel: StatusCellMenuInteractionValidating? { get }

//	isBoostOrFavoriteInteractionAvailable

	var hasMedia: Bool { get }
	var isMediaHidden: Bool { get }
	var isContentHidden: Bool { get }
	var hasSpoiler: Bool { get }
}

protocol StatusCellMenuInteractionValidating {
	var isFavorited: Bool { get }
	var isReblogged: Bool { get }
}
