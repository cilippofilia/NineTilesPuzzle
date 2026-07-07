//
//  PowerUpBadgeButton.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/7/26.
//

import SwiftUI

/// An icon-only power-up button with a small count badge, disabled once the inventory hits
/// zero. `.labelStyle(.iconOnly)` hides the title visually while keeping it as the button's
/// accessibility label.
struct PowerUpBadgeButton: View {
    let type: PowerUpType
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(type.title, systemImage: type.icon, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text(count, format: .number)
                        .font(.caption2.bold())
                        .padding(4)
                        .background(.red, in: .circle)
                        .offset(x: 6, y: -6)
                }
            }
            .disabled(count == 0)
    }
}
