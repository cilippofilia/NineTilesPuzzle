//
//  PowerUpsGuideView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/9/26.
//

import SwiftUI

struct PowerUpsGuideView: View {
    var body: some View {
        List {
            Section {
                PowerUpGuideRow(
                    type: .peek,
                    description: "Re-shows the full source image for a few seconds so you can check your progress against it."
                )

                PowerUpGuideRow(
                    type: .autoPlace,
                    description: "Locks one random unlocked tile into its correct cell for you."
                )

                PowerUpGuideRow(
                    type: .hint,
                    description: "Highlights one out-of-place tile and its home cell — purely informational, it doesn't move anything or cost you a move."
                )

                PowerUpGuideRow(
                    type: .streakFreeze,
                    description: "Cancels the current streak countdown so it can't expire this round."
                )

                PowerUpGuideRow(
                    type: .reshuffle,
                    description: "Scrambles your unlocked tiles among their own positions for a fresh shot at placing them."
                )
            } header: {
                Text("Available Power-ups")
            } footer: {
                Text("Power-ups are earned through play, not purchased. Solve a puzzle to extend a move streak, complete the Daily Challenge, or unlock an achievement, and you'll be awarded one at random.\n\nNot every power-up applies to every mode — Slide's blank-cell mechanic has no locked tiles for Auto-place or Re-shuffle, and Streak Freeze only matters where a streak countdown is running.\n\nTap a power-up's badge along the bottom of the puzzle to use it. Its count decreases by one; when it hits zero the badge disables until you earn more.")
            }
        }
        .navigationTitle("Power-ups")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PowerUpGuideRow: View {
    let type: PowerUpType
    let description: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(type.title)

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
        }
    }
}

#Preview {
    NavigationStack {
        PowerUpsGuideView()
    }
}
