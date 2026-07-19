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
/// it, then the same benefit carousel and a selectable plan list (lifetime pre-selected as
/// the best-value pick), everywhere this sheet is shown. The confirm CTA, Restore Purchase,
/// and the legal links all stay pinned in a bottom safe-area inset rather than scrolling away
/// with the rest of the content.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    let context: PaywallContext

    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private var selectedProduct: Product? {
        [store.monthlyProduct, store.lifetimeProduct]
            .compactMap { $0 }
            .first { $0.id == selectedProductID }
    }

    private var ctaTitle: String {
        guard let selectedProduct else { return "Continue" }
        return selectedProduct.id == StoreManager.lifetimeProductID ? "Unlock Lifetime Access" : "Start Premium Pass"
    }

    // Guideline 3.1.2 requires this disclosure alongside an auto-renewable subscription offer.
    private var subscriptionDisclosure: String {
        "Premium Pass is \(store.monthlyProduct?.displayPrice ?? "$1.99")/month, charged to your Apple ID "
            + "account. It automatically renews unless canceled at least 24 hours before the end of the "
            + "current period. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    PaywallHeaderView(context: context)

                    PaywallBenefitCarousel(benefits: PaywallBenefit.all)
                        .frame(minHeight: 160)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .padding()

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
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    PaywallPlanListView(selectedProductID: $selectedProductID)
                        .padding([.top, .horizontal])

                    PaywallCTAButton(
                        title: ctaTitle,
                        isPurchasing: isPurchasing,
                        isDisabled: isPurchasing || selectedProduct == nil,
                        action: purchaseSelected
                    )
                    .padding()

                    PaywallLegalFooterView(
                        disclosureText: subscriptionDisclosure,
                        isRestoring: isRestoring,
                        onRestore: restore
                    )
                }
                .background(.ultraThinMaterial)
            }
            .scrollContentBackground(.hidden)
            .background(PaywallBackgroundView())
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
