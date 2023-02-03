//
//  InteractionDetailsCellView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 29.01.23.
//  Copyright © 2023 Bruno Philipe. All rights reserved.
//

import Foundation

class InteractionDetailsCellView: MastonautTableCellView {
	
	@IBOutlet var interactionIcon: NSImageView!
	@IBOutlet var interactionLabel: NSButton!
	@IBOutlet var agentAvatarButton: NSButton!

	@IBAction func interactionButtonClicked(_ sender: Any) {}
}
