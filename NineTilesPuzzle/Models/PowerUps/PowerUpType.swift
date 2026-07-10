//
//  PowerUpType.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/7/26.
//

import SwiftUI

/// A power-up earned through play (streak milestones, achievement unlocks, daily-challenge
/// completions) and spent mid-game. See `PowerUpStore` for the inventory and `GameSession`
/// for each power-up's actual effect.
enum PowerUpType: String, CaseIterable, Codable {
    case peek
    case autoPlace
    case hint
    case streakFreeze
    case reshuffle

    var title: String {
        switch self {
        case .peek: "Peek"
        case .autoPlace: "Auto-place"
        case .hint: "Hint"
        case .streakFreeze: "Streak Freeze"
        case .reshuffle: "Re-shuffle"
        }
    }

    var icon: String {
        switch self {
        case .peek: "eye.fill"
        case .autoPlace: "wand.and.stars"
        case .hint: "lightbulb.fill"
        case .streakFreeze: "snowflake"
        case .reshuffle: "shuffle"
        }
    }

    var color: Color {
        switch self {
        case .peek: .blue
        case .autoPlace: .purple
        case .hint: .yellow
        case .streakFreeze: .cyan
        case .reshuffle: .green
        }
    }
}
