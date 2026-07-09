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
        VStack(spacing: 30) {
            Button(action: action) {
                Label(type.title, systemImage: type.icon)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(type.color)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2.bold())
                                .padding(4)
                                .frame(minWidth: 24)
                                .background(.red, in: .circle)
                                .offset(x: 6, y: -6)
                                .contentTransition(.numericText(value: Double(count)))
                        } else {
                            // this will be added back in when IAP is implemented
//                            Text("+")
//                                .font(.caption2.bold())
//                                .padding(3)
//                                .background(.red, in: .circle)
//                                .offset(x: 6, y: -6)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(count == 0) // this will be removed when IAP is implemented
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        PowerUpBadgeButton(type: .peek, count: 2) {}
        PowerUpBadgeButton(type: .autoPlace, count: 1) {}
        PowerUpBadgeButton(type: .hint, count: 99) {}
        PowerUpBadgeButton(type: .streakFreeze, count: 0) {}
        PowerUpBadgeButton(type: .reshuffle, count: 101) {}
    }
    .padding()
}
