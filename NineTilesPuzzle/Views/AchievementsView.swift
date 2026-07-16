//
//  AchievementsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct AchievementsView: View {
    @Environment(AchievementsStore.self) private var achievementsStore
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        let byCategory = achievementsStore.achievementsByCategory(challengeFriendsEnabled: settings.challengeFriendsEnabled)
        let unlocked = achievementsStore.unlockedCount(challengeFriendsEnabled: settings.challengeFriendsEnabled)
        let total = achievementsStore.visibleAchievements(challengeFriendsEnabled: settings.challengeFriendsEnabled).count

        // Skips categories left with no visible achievements (e.g. "Social" when Challenge
        // Friends is off and all its achievements are hidden) — otherwise an empty section
        // still renders its header.
        let nonEmptyCategories = AchievementCategory.allCases.filter { !(byCategory[$0] ?? []).isEmpty }

        List {
            ForEach(nonEmptyCategories, id: \.self) { category in
                Section {
                    ForEach(byCategory[category] ?? []) { achievement in
                        AchievementRowView(achievement: achievement)
                    }
                } header: {
                    Text(category.title)
                }
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(unlocked) / \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
            .environment(AchievementsStore())
            .environment(SettingsStore())
    }
}
