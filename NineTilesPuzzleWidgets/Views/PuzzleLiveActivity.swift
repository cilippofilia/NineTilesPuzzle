//
//  PuzzleLiveActivity.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/4/26.
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The "puzzle in progress" Live Activity: a Lock Screen card and Dynamic Island layouts that
/// show a snapshot of the current board, the mode being played, and how far along the player is —
/// nudging them to come back and finish. The board image is loaded from the shared App Group
/// container by name; only the tiny counters travel through the activity's content state.
struct PuzzleLiveActivity: Widget {
    private let accent = Color.orange

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PuzzleActivityAttributes.self) { context in
            PuzzleLockScreenView(context: context, accent: accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BoardThumbnail(imageName: context.state.boardImageName, cornerRadius: 12)
                        .frame(width: 54, height: 54)
                        .overlay(alignment: .bottomTrailing) {
                            ModeGlyphBadge(icon: context.attributes.gameModeIcon, accent: accent)
                        }
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 5) {
                        StatBadge(icon: "arrow.left.arrow.right",
                                  text: "\(context.state.moveCount)", accent: accent)
                        StatBadge(icon: "clock", text: elapsed(context.state.elapsedTime), accent: accent)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: context.attributes.gameModeIcon)
                                .foregroundStyle(accent)
                            Text("\(context.attributes.gameModeTitle) · \(context.attributes.gridSize)×\(context.attributes.gridSize)")
                                .bold()
                            Text(context.isStale ? "paused" : "in progress")
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            if context.state.currentStreak > 0 {
                                StatBadge(icon: "flame.fill",
                                          text: "\(context.state.currentStreak)", accent: accent)
                            }
                            if context.state.bestStreak > 0 {
                                StatBadge(icon: "trophy.fill",
                                          text: "\(context.state.bestStreak)", accent: .yellow)
                            }
                        }
                        .font(.footnote)

                        // A full-width fill for the previously-empty middle: the ring's linear
                        // twin, turning "how close am I" into the layout's anchor element.
                        HStack(spacing: 8) {
                            ProgressBar(progress: context.state.progress, accent: accent)
                            Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        // Keep the bar off the island's rounded bottom edge.
                        .padding([.horizontal, .bottom], 2)
                    }
                }
            } compactLeading: {
                // While a streak is live the flame is the thing worth glancing at; otherwise
                // fall back to the brand mark so the island still reads as "Nine Tiles".
                if context.state.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("\(context.state.currentStreak)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(accent)
                } else {
                    BrandPuzzleMark()
                }
            } compactTrailing: {
                ProgressRing(progress: context.state.progress, accent: accent)
                    .frame(width: 22, height: 22)
                    // Keep the ring clear of the pill's rounded trailing edge.
                    .padding(.trailing, 2)
            } minimal: {
                ProgressRing(progress: context.state.progress, accent: accent)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(accent)
        }
    }

    private func elapsed(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

private extension PuzzleActivityAttributes {
    static let preview = PuzzleActivityAttributes(
        gameModeTitle: "Slide", gameModeIcon: "arrow.left.arrow.right", gridSize: 4
    )
}

private extension PuzzleActivityAttributes.ContentState {
    // A nonexistent filename is fine: `BoardThumbnail` falls back to a placeholder icon
    // when it can't resolve the image in the shared App Group container.
    static let midGameWithStreak = PuzzleActivityAttributes.ContentState(
        boardImageName: "preview-board", moveCount: 24, elapsedTime: 95,
        currentStreak: 3, bestStreak: 7, progress: 0.6
    )
    static let freshNoStreak = PuzzleActivityAttributes.ContentState(
        boardImageName: "preview-board", moveCount: 3, elapsedTime: 8,
        currentStreak: 0, bestStreak: 7, progress: 0.05
    )
}

#Preview("Lock Screen", as: .content, using: PuzzleActivityAttributes.preview) {
    PuzzleLiveActivity()
} contentStates: {
    PuzzleActivityAttributes.ContentState.midGameWithStreak
    PuzzleActivityAttributes.ContentState.freshNoStreak
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: PuzzleActivityAttributes.preview) {
    PuzzleLiveActivity()
} contentStates: {
    PuzzleActivityAttributes.ContentState.midGameWithStreak
    PuzzleActivityAttributes.ContentState.freshNoStreak
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: PuzzleActivityAttributes.preview) {
    PuzzleLiveActivity()
} contentStates: {
    PuzzleActivityAttributes.ContentState.midGameWithStreak
    PuzzleActivityAttributes.ContentState.freshNoStreak
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: PuzzleActivityAttributes.preview) {
    PuzzleLiveActivity()
} contentStates: {
    PuzzleActivityAttributes.ContentState.midGameWithStreak
    PuzzleActivityAttributes.ContentState.freshNoStreak
}
