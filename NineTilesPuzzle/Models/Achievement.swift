//
//  Achievement.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import Foundation

struct Achievement: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let description: String
    let systemImage: String
    let category: AchievementCategory
    let metric: AchievementMetric
    let target: Int
    let comparison: AchievementComparison
    var isUnlocked: Bool = false
    var unlockedDate: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case systemImage
        case category
        case metric
        case target
        case comparison
    }

    init(
        id: String,
        title: String,
        description: String,
        systemImage: String,
        category: AchievementCategory = .milestones,
        metric: AchievementMetric = .totalGamesPlayed,
        target: Int = 0,
        comparison: AchievementComparison = .greaterThanOrEqual,
        isUnlocked: Bool = false,
        unlockedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.category = category
        self.metric = metric
        self.target = target
        self.comparison = comparison
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
    }
}
