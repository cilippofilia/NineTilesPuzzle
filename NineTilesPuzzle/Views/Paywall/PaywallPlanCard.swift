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
    let showBadge: Bool
    let isSelected: Bool
    let action: () -> Void

    /// Increments only on the false→true transition, so `.symbolEffect(.bounce)` plays for the
    /// card just becoming selected and not for the sibling card simultaneously losing selection.
    @State private var selectionBounce = 0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.green : Color.secondary)
                    .symbolEffect(.bounce, value: selectionBounce)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .bold()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(priceText)
                    .bold()
            }
            .padding()
            .background(alignment: .topTrailing) {
                if showBadge {
                    Text("BEST VALUE")
                        .font(.system(size: 10, weight: .bold))
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.white)
                        .background(.tint)
                        .clipShape(
                            .rect(topLeadingRadius: 0, bottomLeadingRadius: 4, bottomTrailingRadius: 0, topTrailingRadius: 0)
                        )
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassEffect(
            isSelected ? .regular.tint(.green.opacity(0.15)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: 12)
        )
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
                showBadge: false,
                isSelected: false,
                action: {}
            )
            PaywallPlanCard(
                title: "Lifetime VIP Access",
                subtitle: "One-time purchase, yours forever",
                priceText: "$6.99",
                showBadge: true,
                isSelected: true,
                action: {}
            )
        }
    }
    .padding()
}
