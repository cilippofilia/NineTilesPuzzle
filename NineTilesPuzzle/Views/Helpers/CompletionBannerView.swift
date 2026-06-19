//
//  CompletionBannerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct CompletionBannerView: View {
    let gameMode: GameMode
    let streak: Int
    let isNewRecord: Bool
    let moveCount: Int
    let personalBest: Int?
    let elapsedTime: TimeInterval
    let personalBestTime: TimeInterval?
    let isPracticeMode: Bool

    private static let goldColor = Color(hue: 0.12, saturation: 0.9, brightness: 0.85)

    /// A streak of consecutive correct placements isn't meaningful in Slide mode (see
    /// `PuzzleStatusBarView`); the banner shows elapsed time there instead.
    private var showsStreak: Bool { gameMode != .slide }

    var body: some View {
        VStack(spacing: 6) {
            if isNewRecord && showsStreak {
                Label("New Record!", systemImage: "trophy.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
            }
            Text("Completed!")
                .font(.largeTitle)
                .bold()

            if !isPracticeMode {
                HStack(spacing: 20) {
                    if showsStreak {
                        Label("\(streak)", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                            .bold()
                    } else {
                        Label(elapsedTime.formattedMinutesSeconds, systemImage: "clock")
                            .bold()
                    }

                    Label("\(moveCount) moves", systemImage: "arrow.left.arrow.right")
                }

                if showsStreak {
                    if let best = personalBest, best != moveCount {
                        Text("Best: \(best)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else if let best = personalBestTime, best != elapsedTime {
                    Text("Best: \(best.formattedMinutesSeconds)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    VStack(spacing: 20) {
        CompletionBannerView(
            gameMode: .classic,
            streak: 7,
            isNewRecord: true,
            moveCount: 23,
            personalBest: nil,
            elapsedTime: 65,
            personalBestTime: nil,
            isPracticeMode: false
        )
        Spacer()
        CompletionBannerView(
            gameMode: .slide,
            streak: 3,
            isNewRecord: false,
            moveCount: 31,
            personalBest: 23,
            elapsedTime: 47,
            personalBestTime: 52,
            isPracticeMode: false
        )
        Spacer()
        CompletionBannerView(
            gameMode: .classic,
            streak: 0,
            isNewRecord: false,
            moveCount: 18,
            personalBest: nil,
            elapsedTime: 30,
            personalBestTime: nil,
            isPracticeMode: true
        )
    }
}
