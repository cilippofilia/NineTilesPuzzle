//
//  AchievementsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct AchievementsView: View {
    @Environment(PuzzleState.self) private var state

    private var unlockedCount: Int { state.achievements.filter(\.isUnlocked).count }
    private var totalCount: Int { state.achievements.count }

    var body: some View {
        List {
            Section {
                ForEach(state.achievements) { achievement in
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
            .environment(PuzzleState())
    }
}
