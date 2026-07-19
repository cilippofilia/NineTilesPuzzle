//
//  AchievementComparison.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import Foundation

/// How an `Achievement`'s current metric value relates to its `target` for it to unlock.
/// Almost everything is "at least N" (games played, streak length, distinct sizes...);
/// move-count records are the one family where lower is better.
enum AchievementComparison: String, Codable {
    case greaterThanOrEqual
    case lessThanOrEqual

    func isSatisfied(value: Int, target: Int) -> Bool {
        switch self {
        case .greaterThanOrEqual: value >= target
        case .lessThanOrEqual: value <= target
        }
    }
}
