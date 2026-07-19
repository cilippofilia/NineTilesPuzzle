//
//  PaywallProductButton.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import SwiftUI

/// A purchase row on `PaywallView`. `.target` is the lifetime unlock — the emphasized,
/// filled button the Decoy Effect is built around. `.decoy` is the monthly Premium Pass,
/// styled as the lesser option so the lifetime price reads as the obvious value.
struct PaywallProductButton: View {
    enum Emphasis {
        case target
        case decoy
    }

    let title: String
    let subtitle: String
    let priceText: String
    let emphasis: Emphasis
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).bold()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(emphasis == .target ? .white.opacity(0.85) : .secondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(emphasis == .target ? .white : .primary)
                } else {
                    Text(priceText).bold()
                }
            }
            .padding()
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .foregroundStyle(emphasis == .target ? .white : .primary)
        .background(emphasis == .target ? .blue : Color.clear, in: .rect(cornerRadius: 16))
        .overlay {
            if emphasis == .decoy {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.secondary.opacity(0.4), lineWidth: 1)
            }
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 12) {
        PaywallProductButton(
            title: "Premium Pass",
            subtitle: "Monthly, cancel anytime",
            priceText: "$1.99/mo",
            emphasis: .decoy,
            isLoading: false,
            action: {}
        )
        PaywallProductButton(
            title: "Lifetime VIP Access",
            subtitle: "One-time purchase, yours forever",
            priceText: "$6.99",
            emphasis: .target,
            isLoading: false,
            action: {}
        )
    }
    .padding()
}
