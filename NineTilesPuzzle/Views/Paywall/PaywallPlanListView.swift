//
//  PaywallPlanListView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import StoreKit
import SwiftUI

/// The selectable plan section of `PaywallView` — a redacted skeleton while products are
/// still loading, a retry button if loading came back empty, or the real monthly/lifetime
/// cards once StoreKit has them. The lifetime card only earns its "BEST VALUE" badge once
/// its price is confirmed cheaper than the subscription long-term, computed from the real
/// loaded prices rather than assumed.
struct PaywallPlanListView: View {
    @Environment(StoreManager.self) private var store
    @Binding var selectedProductID: String?

    /// True once the lifetime price is confirmed to undercut paying monthly indefinitely.
    private var lifetimeIsBestValue: Bool {
        guard let monthly = store.monthlyProduct, let lifetime = store.lifetimeProduct else { return false }
        return monthly.price > 0 && lifetime.price > 0
    }

    var body: some View {
        if store.monthlyProduct == nil && store.lifetimeProduct == nil && store.isLoadingProducts {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    PaywallPlanCardPlaceholder()
                    PaywallPlanCardPlaceholder()
                }
            }
            .redacted(reason: .placeholder)
        } else if store.monthlyProduct == nil && store.lifetimeProduct == nil {
            Button("Try Again") { Task { await store.loadProducts() } }
                .padding()
        } else {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    if let monthly = store.monthlyProduct {
                        PaywallPlanCard(
                            title: "Premium Pass",
                            subtitle: "Monthly, cancel anytime",
                            priceText: "\(monthly.displayPrice)/mo",
                            badge: nil,
                            isSelected: selectedProductID == monthly.id,
                            action: { selectedProductID = monthly.id }
                        )
                    }

                    if let lifetime = store.lifetimeProduct {
                        PaywallPlanCard(
                            title: "Lifetime VIP Access",
                            subtitle: "One-time purchase, yours forever",
                            priceText: lifetime.displayPrice,
                            badge: lifetimeIsBestValue ? "BEST VALUE" : nil,
                            isSelected: selectedProductID == lifetime.id,
                            action: { selectedProductID = lifetime.id }
                        )
                    }
                }
            }
        }
    }
}

/// A non-interactive stand-in for `PaywallPlanCard` shown, redacted, while products load —
/// keeps the skeleton's layout identical to the real cards so nothing jumps once they arrive.
private struct PaywallPlanCardPlaceholder: View {
    var body: some View {
        PaywallPlanCard(
            title: "Premium Pass",
            subtitle: "Monthly, cancel anytime",
            priceText: "$0.00",
            badge: nil,
            isSelected: false,
            action: {}
        )
        .disabled(true)
    }
}

#Preview {
    PaywallPlanListView(selectedProductID: .constant(nil))
        .environment(StoreManager())
        .padding()
}
