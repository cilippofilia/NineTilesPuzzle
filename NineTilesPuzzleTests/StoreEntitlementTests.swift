//
//  StoreEntitlementTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/18/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("StoreEntitlement")
struct StoreEntitlementTests {
    @Test func noActiveProductsIsLocked() {
        #expect(StoreEntitlement.isPremiumUnlocked(activeProductIDs: []) == false)
    }

    @Test func lifetimeAloneUnlocks() {
        #expect(StoreEntitlement.isPremiumUnlocked(activeProductIDs: [StoreManager.lifetimeProductID]) == true)
    }

    @Test func activeMonthlyAloneUnlocks() {
        #expect(StoreEntitlement.isPremiumUnlocked(activeProductIDs: [StoreManager.monthlyProductID]) == true)
    }

    @Test func expiredOrAbsentMonthlyLeavesLocked() {
        // Transaction.currentEntitlements never yields an expired subscription — an
        // expired monthly is indistinguishable from "never purchased" at this layer.
        #expect(StoreEntitlement.isPremiumUnlocked(activeProductIDs: []) == false)
    }

    @Test func unrelatedProductIDDoesNotUnlock() {
        #expect(StoreEntitlement.isPremiumUnlocked(activeProductIDs: ["some.other.product"]) == false)
    }

    @Test func bothProductsActiveUnlocks() {
        let ids: Set<String> = [StoreManager.lifetimeProductID, StoreManager.monthlyProductID]
        #expect(StoreEntitlement.isPremiumUnlocked(activeProductIDs: ids) == true)
    }
}
