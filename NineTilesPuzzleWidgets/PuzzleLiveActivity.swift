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
                    .frame(width: 18, height: 18)
            } minimal: {
                ProgressRing(progress: context.state.progress, accent: accent)
                    .frame(width: 18, height: 18)
            }
            .keylineTint(accent)
        }
    }

    private func elapsed(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

/// Lock Screen / StandBy presentation: styled board on the left, mode and progress on the right.
private struct PuzzleLockScreenView: View {
    let context: ActivityViewContext<PuzzleActivityAttributes>
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            BoardThumbnail(imageName: context.state.boardImageName, cornerRadius: 14)
                .frame(width: 68, height: 68)
                .overlay(alignment: .bottomTrailing) {
                    ModeGlyphBadge(icon: context.attributes.gameModeIcon, accent: accent, size: 22)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("\(context.attributes.gameModeTitle) · \(context.attributes.gridSize)×\(context.attributes.gridSize)")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    StatBadge(icon: "arrow.left.arrow.right",
                              text: "\(context.state.moveCount)", accent: accent)
                    StatBadge(icon: "clock",
                              text: elapsed(context.state.elapsedTime), accent: accent)
                }

                // Only surfaced while a streak is actually running — the flame is the "keep
                // it alive" nudge, and the trophy rides along as the target to beat when the
                // player has a personal best on the board.
                if context.state.currentStreak > 0 {
                    HStack(spacing: 8) {
                        StatBadge(icon: "flame.fill",
                                  text: "\(context.state.currentStreak)", accent: accent)
                        if context.state.bestStreak > 0 {
                            StatBadge(icon: "trophy.fill",
                                      text: "\(context.state.bestStreak)", accent: .yellow)
                        }
                    }
                }

                Text(context.isStale ? "Paused · tap to resume" : "Tap to keep solving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.55))
    }

    private func elapsed(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

/// The app's brand glyph — a tilted puzzle piece with the red→yellow gradient — used as the
/// Dynamic Island's compact and minimal presentation so the activity reads as "Nine Tiles" at a
/// glance rather than as a mode-specific symbol.
private struct BrandPuzzleMark: View {
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: "puzzlepiece.fill")
            .resizable()
            .scaledToFit()
            .rotationEffect(.degrees(-45))
            .foregroundStyle(
                LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
            )
            .frame(width: size, height: size)
    }
}

/// The mode's SF Symbol in a filled accent disc, tucked into a board thumbnail's bottom-trailing
/// corner. Shared by the Lock Screen card and the Dynamic Island so both read the same way; the
/// glyph, disc, and corner offset all scale from `size`.
private struct ModeGlyphBadge: View {
    let icon: String
    let accent: Color
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(accent.gradient, in: .circle)
            .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 2))
            .offset(x: size * 0.27, y: size * 0.27)
    }
}

/// A slim horizontal fill of the board's completion, spanning the width it's given. The linear
/// counterpart to `ProgressRing`, used as the Dynamic Island's expanded-view anchor element.
private struct ProgressBar: View {
    /// Fraction solved, 0...1.
    let progress: Double
    let accent: Color

    var body: some View {
        Gauge(value: min(1, max(0, progress))) { EmptyView() }
            .gaugeStyle(.linearCapacity)
            .tint(accent)
    }
}

/// A compact circular progress indicator for the Dynamic Island's compact-trailing and minimal
/// slots, showing how many tiles are already home as a ring that fills toward a solved board.
private struct ProgressRing: View {
    /// Fraction solved, 0...1.
    let progress: Double
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 3)
            Circle()
                // A hair of trim so an untouched board still shows a dot rather than nothing.
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// A small pill pairing an icon with a value, used for the move count and elapsed time.
private struct StatBadge: View {
    let icon: String
    let text: String
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(accent)
            Text(text)
                .font(.subheadline.monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.white.opacity(0.12), in: .capsule)
    }
}

/// Loads a board snapshot from the shared container, falling back to a puzzle-piece glyph if the
/// file is missing (e.g. cleaned up between updates), inside a rounded, subtly bordered frame.
private struct BoardThumbnail: View {
    let imageName: String
    let cornerRadius: CGFloat

    var body: some View {
        content
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var content: some View {
        if let url = LiveActivityStore.boardImageURL(named: imageName),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.black.opacity(0.4)
                Image(systemName: "puzzlepiece.fill")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
