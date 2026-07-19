//
//  PaywallView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import StoreKit
import SwiftUI

/// The Hard-Feature Gate paywall — presented whenever a player taps a locked mode, media
/// source, or system-integration feature. Leads with contextual copy for whatever triggered
/// it, then the same fixed benefit list and dual-option pricing (monthly decoy, lifetime
/// target) everywhere, per the Decoy Effect pricing strategy.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let context: PaywallContext

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private static let benefits: [(lead: String, detail: String)] = [
        ("Break the Rules", "Access all 7 game modes, including the chaotic mutations of Chaos "
            + "and the physics-based Haze."),
        ("Make it Personal", "Slice your own camera roll photos or snap pictures in real-time with Quick Snap."),
        ("Claim Your Seat", "Unlock the 3D motion-reactive Wall of Fame, historical calendar archives, "
            + "and all 39 achievements."),
        ("Always Connected", "Live Activities, Dynamic Island tracking, and Home Screen widgets "
            + "for seamless glanceable play.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PaywallHeaderView(context: context)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Self.benefits, id: \.lead) { benefit in
                            PaywallBenefitRow(lead: benefit.lead, detail: benefit.detail)
                        }
                    }
                    .padding()
                    .background(.quaternary, in: .rect(cornerRadius: 16))
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        if let monthly = store.monthlyProduct {
                            PaywallProductButton(
                                title: "Premium Pass",
                                subtitle: "Monthly, cancel anytime",
                                priceText: "\(monthly.displayPrice)/mo",
                                emphasis: .decoy,
                                isLoading: isPurchasing,
                                action: { purchase(monthly) }
                            )
                        }

                        if let lifetime = store.lifetimeProduct {
                            PaywallProductButton(
                                title: "Lifetime VIP Access",
                                subtitle: "One-time purchase, yours forever",
                                priceText: lifetime.displayPrice,
                                emphasis: .target,
                                isLoading: isPurchasing,
                                action: { purchase(lifetime) }
                            )
                        }

                        if store.monthlyProduct == nil && store.lifetimeProduct == nil {
                            if store.isLoadingProducts {
                                ProgressView()
                                    .padding()
                            } else {
                                Button("Try Again") { Task { await store.loadProducts() } }
                                    .padding()
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let errorMessage = errorMessage ?? store.purchaseError {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Guideline 3.1.2 requires this disclosure alongside an auto-renewable
                    // subscription offer.
                    Text("Premium Pass is \(store.monthlyProduct?.displayPrice ?? "$1.99")/month, charged to your "
                        + "Apple ID account. It automatically renews unless canceled at least 24 hours before the "
                        + "end of the current period. Manage or cancel anytime in Settings > Apple ID > "
                        + "Subscriptions.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if isRestoring {
                        ProgressView()
                    } else {
                        Button("Restore Purchase") { restore() }
                            .font(.footnote)
                    }

                    HStack(spacing: 16) {
                        Button("Terms of Use") { openURL(PaywallLegalLinks.termsOfUse) }
                        Button("Privacy Policy") { openURL(PaywallLegalLinks.privacyPolicy) }
                    }
                    .font(.caption)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                guard store.monthlyProduct == nil || store.lifetimeProduct == nil else { return }
                await store.loadProducts()
            }
            .onChange(of: store.isPremiumUnlocked) { _, isUnlocked in
                if isUnlocked { dismiss() }
            }
        }
    }

    private func purchase(_ product: Product) {
        errorMessage = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                try await store.purchase(product)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        errorMessage = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            await store.restore()
        }
    }
}

#Preview {
    PaywallView(context: .gameMode(.fog))
        .environment(StoreManager())
}
