//
//  PremiumFeature.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import Foundation

/// A screen or capability behind the Hard-Feature Gate paywall. Deliberately StoreKit-free
/// and `Sendable` so the "is this locked" decision is a pure function, testable without any
/// store/transaction plumbing. `StoreManager` supplies the live `isPremiumUnlocked` value;
/// this type only knows how to interpret it per-feature.
enum PremiumFeature: Sendable, Hashable {
    case gameMode(GameMode)
    case imageSource(MediaSourceType)
    case liveActivities
    case widgets
    case wallOfFame
    case achievementsArchive
    case dailyArchive

    /// Whether this feature requires a premium unlock, independent of the player's current
    /// entitlement. Game modes and image sources delegate to their own `isFree`; every other
    /// case here is unconditionally premium.
    var isFree: Bool {
        switch self {
        case .gameMode(let mode): mode.isFree
        case .imageSource(let source): source.isFree
        case .liveActivities, .widgets, .wallOfFame, .achievementsArchive, .dailyArchive: false
        }
    }

    /// Whether this feature is locked for a player with the given entitlement state.
    func isLocked(isPremiumUnlocked: Bool) -> Bool {
        !isFree && !isPremiumUnlocked
    }
}
