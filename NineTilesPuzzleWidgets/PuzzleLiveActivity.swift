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
/// show a snapshot of the current board plus move count and elapsed time, nudging the player to
/// come back and finish. The board image is loaded from the shared App Group container by name;
/// only the tiny counters travel through the activity's content state.
struct PuzzleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PuzzleActivityAttributes.self) { context in
            PuzzleLockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.4))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BoardThumbnail(imageName: context.state.boardImageName)
                        .frame(width: 44, height: 44)
                        .clipShape(.rect(cornerRadius: 8))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Label("\(context.state.moveCount)", systemImage: "hand.tap")
                            .font(.subheadline.monospacedDigit())
                        ElapsedTimeText(seconds: context.state.elapsedTime)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.gameModeTitle) · \(context.attributes.gridSize)×\(context.attributes.gridSize) in progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                BoardThumbnail(imageName: context.state.boardImageName)
                    .frame(width: 20, height: 20)
                    .clipShape(.rect(cornerRadius: 4))
            } compactTrailing: {
                Label("\(context.state.moveCount)", systemImage: "hand.tap")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                BoardThumbnail(imageName: context.state.boardImageName)
                    .frame(width: 20, height: 20)
                    .clipShape(.rect(cornerRadius: 4))
            }
            .keylineTint(.orange)
        }
    }
}

/// Lock Screen / StandBy presentation: board on the left, progress on the right.
private struct PuzzleLockScreenView: View {
    let context: ActivityViewContext<PuzzleActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            BoardThumbnail(imageName: context.state.boardImageName)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.attributes.gameModeTitle) · \(context.attributes.gridSize)×\(context.attributes.gridSize)")
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(context.state.moveCount)", systemImage: "hand.tap")
                    ElapsedTimeText(seconds: context.state.elapsedTime)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.monospacedDigit())

                Text("Tap to keep solving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}

/// Loads a board snapshot from the shared container, falling back to a puzzle-piece glyph if the
/// file is missing (e.g. cleaned up between updates).
private struct BoardThumbnail: View {
    let imageName: String

    var body: some View {
        if let url = LiveActivityStore.boardImageURL(named: imageName),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "puzzlepiece.fill")
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(.secondary)
        }
    }
}

/// Formats a frozen elapsed-time value as m:ss. The puzzle clock pauses while backgrounded, so a
/// static label (rather than a live-counting timer) matches the game's own behavior.
private struct ElapsedTimeText: View {
    let seconds: TimeInterval

    var body: some View {
        Text(Duration.seconds(seconds), format: .time(pattern: .minuteSecond))
    }
}
