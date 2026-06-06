//
//  StatsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct StatsView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Streaks") {
                    LabeledContent("Current Streak") {
                        Text(state.currentStreak > 0 ? "\(state.currentStreak)" : "--")
                            .foregroundStyle(state.currentStreak > 0 ? .primary : .secondary)
                    }
                    LabeledContent("Best Streak") {
                        Text(state.allTimeHighStreak > 0 ? "\(state.allTimeHighStreak)" : "--")
                            .foregroundStyle(state.allTimeHighStreak > 0 ? .primary : .secondary)
                    }
                }

                Section("Personal Bests") {
                    ForEach(3...8, id: \.self) { size in
                        let best = state.personalBestMoves[size]
                        LabeledContent(difficultyLabel(for: size)) {
                            Text(best.map { "\($0) moves" } ?? "--")
                                .foregroundStyle(best != nil ? .primary : .secondary)
                        }
                    }
                }

                Section("Games Played") {
                    ForEach(3...8, id: \.self) { size in
                        let count = state.gamesPlayed[size]
                        LabeledContent(difficultyLabel(for: size)) {
                            Text(count.map { "\($0)" } ?? "--")
                                .foregroundStyle(count != nil ? .primary : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension StatsView {
    func difficultyLabel(for size: Int) -> String {
        switch size {
        case 3: "Easy (3×3)"
        case 4: "Medium (4×4)"
        case 5: "Hard (5×5)"
        case 6: "Expert (6×6)"
        case 7: "Master (7×7)"
        default: "Insane (8×8)"
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StatsView()
                .environment(PuzzleState())
        }
}
