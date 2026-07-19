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

    private(set) var hasActiveEntitlement = false
    private(set) var activeProductIDs: Set<String> = []
    private(set) var lifetimeProduct: Product?
    private(set) var monthlyProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var purchaseError: String?
    /// Set when a purchase returns `.pending` (Ask to Buy, SCA, etc.) so the paywall can show
    /// neutral "awaiting approval" messaging instead of silently doing nothing.
    private(set) var pendingApprovalMessage: String?

    /// True when the active entitlement is the auto-renewable Premium Pass rather than the
    /// lifetime non-consumable — drives whether Settings offers the native manage-subscription
    /// sheet, which has nothing to show a lifetime-only purchaser.
    var hasActiveSubscription: Bool {
        activeProductIDs.contains(Self.monthlyProductID)
    }

    /// Lets Settings' Dev Tools "Force VIP Unlocked" toggle simulate premium without a
    /// sandbox purchase — mirrors `GameSession`'s injected `isPremiumUnlocked` closure.
    private let debugOverride: () -> Bool

    /// Lets Settings' Dev Tools "Remove VIP Lifetime Access" button suppress a real
    /// entitlement (or the force-unlock override) so the non-VIP experience can be tested
    /// without deleting the transaction in Xcode's StoreKit Transaction Manager.
    private let debugForceRemoved: () -> Bool

    /// True if a real StoreKit entitlement is active or the force-unlock override is on,
    /// unless the debug removal override is suppressing access — that wins over both.
    var isPremiumUnlocked: Bool {
        (hasActiveEntitlement || debugOverride()) && !debugForceRemoved()
    }

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

    init(
        debugOverride: @escaping () -> Bool = { false },
        debugForceRemoved: @escaping () -> Bool = { false }
    ) {
        self.debugOverride = debugOverride
        self.debugForceRemoved = debugForceRemoved
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

    /// `Product.products(for:)` can return a partial result — some IDs missing but no error
    /// thrown — while StoreKit's local/remote catalog is still warming up right after launch.
    /// Retries a few times on a short delay so a cold start doesn't strand the paywall with
    /// only one of the two products.
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        let requestedIDs: Set<String> = [Self.lifetimeProductID, Self.monthlyProductID]
        do {
            for attempt in 0..<3 {
                let products = try await Product.products(for: requestedIDs)
                lifetimeProduct = products.first { $0.id == Self.lifetimeProductID }
                monthlyProduct = products.first { $0.id == Self.monthlyProductID }
                if Set(products.map(\.id)) == requestedIDs { break }
                if attempt < 2 { try? await Task.sleep(for: .milliseconds(500)) }
            }
            purchaseError = nil
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async throws {
        purchaseError = nil
        pendingApprovalMessage = nil
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await refreshEntitlement()
        case .pending:
            pendingApprovalMessage = "This purchase needs approval — from a family organizer, or your bank. "
                + "It'll unlock automatically as soon as it's approved."
        case .userCancelled:
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

    /// Re-mirrors `isPremiumUnlocked` into the shared App Group after the debug override
    /// flips, without re-running the `Transaction.currentEntitlements` scan that
    /// `refreshEntitlement()` does.
    func syncWidgetEntitlementForDebugOverride() {
        widgetData.updateEntitlement(isPremiumUnlocked: isPremiumUnlocked)
    }

    func refreshEntitlement() async {
        var activeProductIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            activeProductIDs.insert(transaction.productID)
        }
        self.activeProductIDs = activeProductIDs
        hasActiveEntitlement = StoreEntitlement.isPremiumUnlocked(activeProductIDs: activeProductIDs)
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
