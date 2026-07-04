//
//  PuzzleLockScreenView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI
import WidgetKit

/// Lock Screen / StandBy presentation: styled board on the left, mode and progress on the right.
struct PuzzleLockScreenView: View {
    let context: ActivityViewContext<PuzzleActivityAttributes>
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            BoardThumbnail(imageName: context.state.boardImageName, cornerRadius: 14)
                .frame(width: 68, height: 68)
                .overlay(alignment: .bottomTrailing) {
                    ModeGlyphBadge(icon: context.attributes.gameModeIcon, accent: accent, size: 22)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(context.attributes.gameModeTitle) · \(context.attributes.gridSize)×\(context.attributes.gridSize)")
                    .font(.headline)
                    .lineLimit(1)

                // All four stats on one line: moves/clock leading, streak/best pushed to the
                // trailing edge so the row spans the full card width. Streak and its target
                // only appear while a streak is actually running.
                HStack(spacing: 8) {
                    StatBadge(icon: "arrow.left.arrow.right",
                              text: "\(context.state.moveCount)", accent: accent)
                    StatBadge(icon: "clock",
                              text: elapsed(context.state.elapsedTime), accent: accent)
                    if context.state.currentStreak > 0 {
                        Spacer(minLength: 8)
                        StatBadge(icon: "flame.fill",
                                  text: "\(context.state.currentStreak)", accent: accent)
                        if context.state.bestStreak > 0 {
                            StatBadge(icon: "trophy.fill",
                                      text: "\(context.state.bestStreak)", accent: .yellow)
                        }
                    }
                }

                // Full-width completion bar spanning the whole card — the horizontal element
                // that keeps the layout from bunching to the leading edge.
                HStack(spacing: 8) {
                    ProgressBar(progress: context.state.progress, accent: accent)
                    Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(context.isStale ? "Paused · tap to resume" : "Tap to keep solving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.55))
    }

    private func elapsed(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
