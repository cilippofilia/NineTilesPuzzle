//
//  LiveActivityController.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import ActivityKit
import CoreGraphics
import Foundation

/// Everything the controller needs to render one board snapshot and update the Live Activity.
/// Assembled by `GameSession` from the live board so the controller stays decoupled from it.
struct LiveActivityBoardInput {
    var placements: [PuzzleBoardSnapshot.Placement]
    var tileImages: [Int: CGImage]
    var gridSize: Int
    /// Slide mode's empty cell (tile id to leave undrawn), or `nil` for modes without one.
    var blankTileID: Int?
    var gameModeTitle: String
    var moveCount: Int
    var elapsedTime: TimeInterval
}

/// Owns the lifecycle of the "puzzle in progress" Live Activity: starting it when a game begins,
/// refreshing its board snapshot when the app is backgrounded, and ending it the moment the game
/// is over. Every method no-ops safely when Live Activities are disabled or unavailable (e.g. in
/// unit tests), so callers can wire it in unconditionally.
@MainActor
final class LiveActivityController {
    private var activity: Activity<PuzzleActivityAttributes>?
    /// The snapshot file currently referenced by the activity, tracked so it can be cleaned up
    /// once superseded or when the activity ends.
    private var currentImageName: String?

    /// Whether the user has Live Activities enabled for this app.
    private var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Starts a fresh Live Activity for the given board, ending any previous one first so two
    /// never run at once (e.g. across a "Play Again"). No-ops if Live Activities are disabled or
    /// the snapshot can't be written to the shared container.
    func start(_ input: LiveActivityBoardInput) {
        guard isEnabled else { return }
        end()

        guard let imageName = writeSnapshot(input) else { return }
        let attributes = PuzzleActivityAttributes(
            gameModeTitle: input.gameModeTitle,
            gridSize: input.gridSize
        )
        let content = ActivityContent(state: state(imageName: imageName, input: input), staleDate: nil)

        do {
            activity = try Activity.request(attributes: attributes, content: content)
            currentImageName = imageName
        } catch {
            // Requesting can fail (system limits, permission races). Nothing else to do — the
            // game plays on regardless; we just don't get the reminder this time.
            removeSnapshot(named: imageName)
        }
    }

    /// Refreshes the running activity with the current board and counters. No-ops if no activity
    /// is running (nothing to remind about) or the new snapshot can't be written.
    func refresh(_ input: LiveActivityBoardInput) {
        guard let activity else { return }
        guard let imageName = writeSnapshot(input) else { return }

        let previous = currentImageName
        currentImageName = imageName
        let content = ActivityContent(state: state(imageName: imageName, input: input), staleDate: nil)

        Task {
            await activity.update(content)
            // Drop the superseded snapshot only after the update lands, so the widget never
            // reads a file we've already deleted.
            if let previous, previous != imageName { removeSnapshot(named: previous) }
        }
    }

    /// Ends the running activity immediately and cleans up its snapshot file. Safe to call when
    /// nothing is running.
    func end() {
        guard let finishing = activity else { return }
        let imageName = currentImageName
        activity = nil
        currentImageName = nil

        Task {
            await finishing.end(nil, dismissalPolicy: .immediate)
            if let imageName { removeSnapshot(named: imageName) }
        }
    }

    private func state(imageName: String, input: LiveActivityBoardInput) -> PuzzleActivityAttributes.ContentState {
        PuzzleActivityAttributes.ContentState(
            boardImageName: imageName,
            moveCount: input.moveCount,
            elapsedTime: input.elapsedTime
        )
    }

    /// Composites the board and writes it to a uniquely named file in the shared container,
    /// returning the filename to reference from the content state.
    private func writeSnapshot(_ input: LiveActivityBoardInput) -> String? {
        guard let data = PuzzleBoardSnapshot.pngData(
            placements: input.placements,
            images: input.tileImages,
            gridSize: input.gridSize,
            blankTileID: input.blankTileID
        ) else { return nil }

        guard let container = LiveActivityStore.containerURL else { return nil }
        let name = "board-\(UUID().uuidString).png"
        do {
            try data.write(to: container.appending(path: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    private func removeSnapshot(named name: String) {
        guard let url = LiveActivityStore.boardImageURL(named: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
