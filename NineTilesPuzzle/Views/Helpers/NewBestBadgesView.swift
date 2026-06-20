//
//  NewBestBadgesView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import SwiftUI

/// Floats below the completion banner as its own layer rather than growing the banner's
/// card, so the card's height stays fixed regardless of how many badges are showing.
struct NewBestBadgesView: View {
    let showsStreak: Bool
    let moveCount: Int
    let isNewMovesRecord: Bool
    let elapsedTime: TimeInterval
    let isNewBestTime: Bool
    var isNewTimeTrialScoreRecord: Bool = false
    var timeTrialScore: Int = 0
    var isNewLadderScoreRecord: Bool = false
    var ladderCumulativeScore: Int = 0
    var isNewLadderStageRecord: Bool = false
    var ladderStageReached: Int = 0

    private static let goldColor = Color(hue: 0.12, saturation: 0.9, brightness: 0.85)

    var body: some View {
        VStack(spacing: 8) {
            if isNewMovesRecord {
                Label("New Best! \(moveCount) moves", systemImage: "medal.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .clipShape(.capsule)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            if !showsStreak && isNewBestTime {
                Label("New Best Time! \(elapsedTime.formattedMinutesSeconds)", systemImage: "medal.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .clipShape(.capsule)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            if isNewTimeTrialScoreRecord {
                Label("New Best Score! \(timeTrialScore)", systemImage: "medal.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .clipShape(.capsule)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            if isNewLadderScoreRecord {
                Label("New Best Run Score! \(ladderCumulativeScore)", systemImage: "medal.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .clipShape(.capsule)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            if isNewLadderStageRecord {
                Label("New Furthest Stage! Stage \(ladderStageReached)", systemImage: "medal.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .clipShape(.capsule)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NewBestBadgesView(showsStreak: true, moveCount: 23, isNewMovesRecord: true, elapsedTime: 65, isNewBestTime: false)
        NewBestBadgesView(showsStreak: false, moveCount: 31, isNewMovesRecord: true, elapsedTime: 38, isNewBestTime: true)
        NewBestBadgesView(showsStreak: true, moveCount: 14, isNewMovesRecord: false, elapsedTime: 38, isNewBestTime: false, isNewTimeTrialScoreRecord: true, timeTrialScore: 5300)
        NewBestBadgesView(showsStreak: true, moveCount: 12, isNewMovesRecord: false, elapsedTime: 30, isNewBestTime: false, isNewLadderScoreRecord: true, ladderCumulativeScore: 32000, isNewLadderStageRecord: true, ladderStageReached: 10)
    }
}
