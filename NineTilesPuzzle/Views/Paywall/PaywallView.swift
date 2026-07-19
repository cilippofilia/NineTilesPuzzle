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
/// it, then the same fixed benefit list and a selectable plan list (lifetime pre-selected as
/// the best-value pick) confirmed with a single CTA, everywhere this sheet is shown.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let context: PaywallContext

    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private static let benefits: [(lead: String, detail: String, icon: String, tint: Color)] = [
        ("Break the Rules", "Access all 7 game modes, including the chaotic mutations of Chaos "
            + "and the physics-based Haze.", "gamecontroller.fill", .purple),
        ("Make it Personal", "Slice your own camera roll photos or snap pictures in real-time with Quick Snap.",
            "camera.fill", .pink),
        ("Claim Your Seat", "Unlock the 3D motion-reactive Wall of Fame, the full Daily Challenge archive, "
            + "and all 39 achievements.", "trophy.fill", .orange),
        ("Always Connected", "Live Activities, Dynamic Island tracking, and Home Screen widgets "
            + "so you can check your game at a glance.", "widget.small.badge.plus", .blue)
    ]

    private var selectedProduct: Product? {
        [store.monthlyProduct, store.lifetimeProduct]
            .compactMap { $0 }
            .first { $0.id == selectedProductID }
    }

    private var ctaTitle: String {
        guard let selectedProduct else { return "Continue" }
        return selectedProduct.id == StoreManager.lifetimeProductID ? "Unlock Lifetime Access" : "Start Premium Pass"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PaywallHeaderView(context: context)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Self.benefits, id: \.lead) { benefit in
                            PaywallBenefitRow(
                                icon: benefit.icon,
                                tint: benefit.tint,
                                lead: benefit.lead,
                                detail: benefit.detail
                            )
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .padding(.horizontal)

                    PaywallPlanListView(selectedProductID: $selectedProductID)
                        .padding(.horizontal)

                    if let message = store.pendingApprovalMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else if let errorMessage = errorMessage ?? store.purchaseError {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    PaywallCTAButton(
                        title: ctaTitle,
                        isPurchasing: isPurchasing,
                        isDisabled: isPurchasing || selectedProduct == nil,
                        action: purchaseSelected
                    )
                    .padding(.horizontal)

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
                if store.monthlyProduct == nil || store.lifetimeProduct == nil {
                    await store.loadProducts()
                }
                if selectedProductID == nil {
                    selectedProductID = store.lifetimeProduct?.id ?? store.monthlyProduct?.id
                }
            }
            .onChange(of: store.lifetimeProduct?.id) { _, newID in
                if selectedProductID == nil { selectedProductID = newID }
            }
            .onChange(of: store.isPremiumUnlocked) { _, isUnlocked in
                if isUnlocked { dismiss() }
            }
        }
    }

    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
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
