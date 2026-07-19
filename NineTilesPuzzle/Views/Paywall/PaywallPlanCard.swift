//
//  PaywallPlanCard.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// A tappable, selectable plan row on `PaywallView`. The player picks one card — shown via a
/// filled radio glyph and tinted glass — then confirms with the single CTA button below the
/// list, rather than each row being its own independent buy button.
struct PaywallPlanCard: View {
    let title: String
    let subtitle: String
    let priceText: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    /// Increments only on the false→true transition, so `.symbolEffect(.bounce)` plays for the
    /// card just becoming selected and not for the sibling card simultaneously losing selection.
    @State private var selectionBounce = 0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.green : Color.secondary)
                    .symbolEffect(.bounce, value: selectionBounce)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title).bold()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(priceText).bold()
            }
            .padding()
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassEffect(
            isSelected ? .regular.tint(.green.opacity(0.25)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.tint, in: .capsule)
                    .offset(x: 8, y: -8)
            }
        }
        .animation(.snappy, value: isSelected)
        .onChange(of: isSelected) { _, newValue in
            if newValue { selectionBounce += 1 }
        }
    }
}

#Preview {
    GlassEffectContainer(spacing: 12) {
        VStack(spacing: 12) {
            PaywallPlanCard(
                title: "Premium Pass",
                subtitle: "Monthly, cancel anytime",
                priceText: "$1.99/mo",
                badge: nil,
                isSelected: false,
                action: {}
            )
            PaywallPlanCard(
                title: "Lifetime VIP Access",
                subtitle: "One-time purchase, yours forever",
                priceText: "$6.99",
                badge: "BEST VALUE",
                isSelected: true,
                action: {}
            )
        }
    }
    .padding()
}
