//
//  PaywallBenefit.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// One slide in `PaywallBenefitCarousel` — a colored icon badge, a bold lead-in phrase, and a
/// supporting sentence describing one thing a membership unlocks.
struct PaywallBenefit: Identifiable {
    var id: String { lead }

    let lead: String
    let detail: String
    let icon: String
    let tint: Color

    static let all: [PaywallBenefit] = [
        PaywallBenefit(
            lead: "Break the Rules",
            detail: "Access all 7 game modes, including the chaotic mutations of Chaos and the physics-based Haze.",
            icon: "gamecontroller.fill",
            tint: .purple
        ),
        PaywallBenefit(
            lead: "Make it Personal",
            detail: "Slice your own camera roll photos or snap pictures in real-time with Quick Snap.",
            icon: "camera.fill",
            tint: .pink
        ),
        PaywallBenefit(
            lead: "Claim Your Seat",
            detail: "Unlock the 3D motion-reactive Wall of Fame, the full Daily Challenge archive, "
                + "and all the achievements.",
            icon: "trophy.fill",
            tint: .orange
        ),
        PaywallBenefit(
            lead: "Always Connected",
            detail: "Live Activities, Dynamic Island tracking, and Home Screen widgets "
                + "so you can check your game at a glance.",
            icon: "widget.small.badge.plus",
            tint: .blue
        ),
        PaywallBenefit(
            lead: "Play Uninterrupted",
            detail: "No cross-promo ads between games — just you and the puzzle.",
            icon: "nosign",
            tint: .red
        )
    ]
}
