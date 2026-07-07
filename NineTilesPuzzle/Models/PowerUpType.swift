//
//  PowerUpType.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/7/26.
//

import Foundation

/// A power-up earned through play (streak milestones, achievement unlocks, daily-challenge
/// completions) and spent mid-game. See `PowerUpStore` for the inventory and `GameSession`
/// for each power-up's actual effect.
enum PowerUpType: String, CaseIterable, Codable {
    case peek
    case autoPlace

    var title: String {
        switch self {
        case .peek: "Peek"
        case .autoPlace: "Auto-place"
        }
    }

    var icon: String {
        switch self {
        case .peek: "eye.fill"
        case .autoPlace: "wand.and.stars"
        }
    }
}
