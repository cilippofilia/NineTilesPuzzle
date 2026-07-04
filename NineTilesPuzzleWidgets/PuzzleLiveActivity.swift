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
                    BoardThumbnail(imageName: context.state.boardImageName, cornerRadius: 9)
                        .frame(width: 46, height: 46)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        StatBadge(icon: context.attributes.gameModeIcon,
                                  text: "\(context.state.moveCount)", accent: accent)
                        StatBadge(icon: "clock", text: elapsed(context.state.elapsedTime), accent: accent)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 5) {
                        Image(systemName: context.attributes.gameModeIcon)
                            .foregroundStyle(accent)
                        Text("\(context.attributes.gameModeTitle) · \(context.attributes.gridSize)×\(context.attributes.gridSize)")
                            .bold()
                        Text("in progress")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            } compactLeading: {
                Image(systemName: context.attributes.gameModeIcon)
                    .foregroundStyle(accent)
            } compactTrailing: {
                Text("\(context.state.moveCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(accent)
            } minimal: {
                Image(systemName: context.attributes.gameModeIcon)
                    .foregroundStyle(accent)
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
                    Image(systemName: context.attributes.gameModeIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(accent.gradient, in: .circle)
                        .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 2))
                        .offset(x: 6, y: 6)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("\(context.attributes.gameModeTitle) · \(context.attributes.gridSize)×\(context.attributes.gridSize)")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    StatBadge(icon: context.attributes.gameModeIcon,
                              text: "\(context.state.moveCount)", accent: accent)
                    StatBadge(icon: "clock",
                              text: elapsed(context.state.elapsedTime), accent: accent)
                }

                Text("Tap to keep solving")
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
