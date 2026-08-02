//
//  PaywallContext.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import Foundation

/// What triggered the paywall — drives `PaywallView`'s headline, blurb, and icon so the sheet
/// feels contextual to whatever the player just tapped rather than a single generic upsell.
struct PaywallContext: Identifiable, Hashable {
    var id: String { headline }

    let headline: String
    let subheadline: String
    let icon: PaywallIcon

    static func gameMode(_ mode: GameMode) -> PaywallContext {
        PaywallContext(headline: mode.title, subheadline: mode.description, icon: .symbol(mode.icon))
    }

    static func imageSource(_ source: MediaSourceType) -> PaywallContext {
        switch source {
        case .local:
            PaywallContext(
                headline: "From Photos",
                subheadline: "Turn your own camera roll into a puzzle — solve pictures of your pets, "
                    + "your family, your favorite places.",
                icon: .symbol("photo.on.rectangle.angled")
            )
        case .camera:
            PaywallContext(
                headline: "Quick Snap",
                subheadline: "Snap whatever's in front of you on a countdown, then solve it while it's still fresh "
                    + "— no retakes.",
                icon: .symbol("camera.fill")
            )
        case .mixed:
            PaywallContext(
                headline: "Mixed Pics",
                subheadline: "Every game keeps you guessing — a random pick from the internet or your own library.",
                icon: .symbol("shuffle")
            )
        case .random, .numbers:
            PaywallContext(headline: source.label, subheadline: "", icon: .symbol("photo"))
        }
    }

    static let wallOfFame = PaywallContext(
        headline: "Wall of Fame",
        subheadline: "Pin your best solves to a motion-reactive corkboard and watch them swing as you tilt your phone.",
        icon: .symbol("photo.artframe")
    )

    static let achievementsArchive = PaywallContext(
        headline: "Achievements",
        subheadline: "Track all the achievements across 6 categories — your full record of every milestone "
            + "along the way.",
        icon: .symbol("trophy.fill")
    )

    static let dailyArchive = PaywallContext(
        headline: "Daily Challenge Archive",
        subheadline: "Browse the calendar and replay any past Daily Challenge you've missed or want another shot at.",
        icon: .symbol("calendar")
    )

    static let removeAds = PaywallContext(
        headline: "Remove Ads",
        subheadline: "No more cross-promo interruptions between games — just you and the puzzle.",
        icon: .symbol("nosign")
    )

    static let systemIntegration = PaywallContext(
        headline: "Always Connected",
        subheadline: "Live Activities, Dynamic Island tracking, and Home Screen widgets keep your game "
            + "glanceable without opening the app.",
        icon: .symbol("widget.small.badge.plus")
    )

    static let general = PaywallContext(
        headline: "Nine Tiles Puzzle VIP",
        subheadline: "Unlock every game mode, personalize puzzles with your own photos, and get the full experience.",
        icon: .appIcon
    )
}

/// Either a system symbol name or the app's own icon — `PaywallHeaderView` renders the two
/// quite differently, so this stays a payload enum rather than plain `String`.
enum PaywallIcon: Hashable {
    case symbol(String)
    case appIcon
}
