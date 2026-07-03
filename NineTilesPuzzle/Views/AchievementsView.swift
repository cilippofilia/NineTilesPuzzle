//
//  AchievementsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct AchievementsView: View {
    @Environment(AchievementsStore.self) private var achievementsStore

    var body: some View {
        List {
            ForEach(AchievementCategory.allCases, id: \.self) { category in
                Section {
                    ForEach(achievementsStore.achievementsByCategory[category] ?? []) { achievement in
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
                Text("\(achievementsStore.unlockedCount) / \(achievementsStore.achievements.count)")
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
    }
}
