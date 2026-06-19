//
//  AchievementsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct AchievementsView: View {
    @Environment(AchievementsStore.self) private var achievementsStore

    private var unlockedCount: Int { achievementsStore.achievements.filter(\.isUnlocked).count }
    private var totalCount: Int { achievementsStore.achievements.count }

    var body: some View {
        List {
            Section {
                ForEach(achievementsStore.achievements) { achievement in
                    AchievementRowView(achievement: achievement)
                }
            } header: {
                Text("\(unlockedCount) of \(totalCount) unlocked")
                    .font(.subheadline)
                    .textCase(nil)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
            .environment(AchievementsStore())
    }
}
