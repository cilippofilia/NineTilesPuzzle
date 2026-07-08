//
//  AchievementCategory.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import Foundation

enum AchievementCategory: String, Codable, CaseIterable {
    case milestones
    case difficulty
    case efficiency
    case streaks
    case explorer
    case special
    case social

    var title: String {
        switch self {
        case .milestones: "Milestones"
        case .difficulty: "Difficulty"
        case .efficiency: "Efficiency"
        case .streaks: "Streaks"
        case .explorer: "Explorer"
        case .special: "Special"
        case .social: "Social"
        }
    }
}
