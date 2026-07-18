//
//  StoreManager.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import Foundation
import StoreKit

/// Pure decision logic for turning a set of currently-active product IDs into an
/// entitlement flag. Kept separate from `StoreManager` (and `nonisolated`, unlike the
/// `@MainActor` store) so the "which purchases unlock premium" rule is testable without
/// any StoreKit transaction plumbing.
enum StoreEntitlement {
    /// Premium unlocks with either the lifetime non-consumable or a currently-active
    /// monthly subscription. `activeProductIDs` is expected to already be filtered down
    /// to entitlements that are active right now — an expired subscription simply isn't
    /// a member of the set, the same way `Transaction.currentEntitlements` excludes it.
    static func isPremiumUnlocked(activeProductIDs: Set<String>) -> Bool {
        activeProductIDs.contains(StoreManager.lifetimeProductID)
            || activeProductIDs.contains(StoreManager.monthlyProductID)
    }
}

/// Owns the app's premium entitlement: loads the two StoreKit 2 products, derives
/// `isPremiumUnlocked` from `Transaction.currentEntitlements`, handles purchases and
/// restores, and mirrors the flag into the shared App Group so the widget extension and
/// Live Activity can read it without linking StoreKit themselves.
@MainActor
@Observable
final class StoreManager {
    nonisolated static let lifetimeProductID = "cilia.filippo.NineTilesPuzzle.lifetime"
    nonisolated static let monthlyProductID = "cilia.filippo.NineTilesPuzzle.monthly"

    private(set) var isPremiumUnlocked = false
    private(set) var lifetimeProduct: Product?
    private(set) var monthlyProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var purchaseError: String?

    // `@ObservationIgnored` since this is a private implementation detail no view reads —
    // it also sidesteps an `@Observable`-macro conflict between tracked-property synthesis
    // and `nonisolated`. `Task` is `Sendable` and `cancel()` is thread-safe, so it's safe to
    // reach past actor isolation here: `deinit` on a `@MainActor` class runs nonisolated,
    // and can't `await` its way onto the actor to cancel this normally.
    @ObservationIgnored
    nonisolated(unsafe) private var transactionListenerTask: Task<Void, Never>?

    /// Owns the actual App Group write and the paired `WidgetCenter` reload — mirrors
    /// `GameSession`'s use of the same controller for the daily section.
    private let widgetData = WidgetDataController()

    init() {
        transactionListenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    /// Loads the storefront products and refreshes entitlement. Call once from the app
    /// root at launch.
    func start() async {
        await loadProducts()
        await refreshEntitlement()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [Self.lifetimeProductID, Self.monthlyProductID])
            lifetimeProduct = products.first { $0.id == Self.lifetimeProductID }
            monthlyProduct = products.first { $0.id == Self.monthlyProductID }
            purchaseError = nil
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async throws {
        purchaseError = nil
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await refreshEntitlement()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = error.localizedDescription
        }
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var activeProductIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            activeProductIDs.insert(transaction.productID)
        }
        isPremiumUnlocked = StoreEntitlement.isPremiumUnlocked(activeProductIDs: activeProductIDs)
        // Mirrors the flag into the shared App Group so the widget extension — which never
        // links StoreKit — can read entitlement without a round trip through the app.
        widgetData.updateEntitlement(isPremiumUnlocked: isPremiumUnlocked)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlement()
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreManagerError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreManagerError: Error {
    case failedVerification
}
