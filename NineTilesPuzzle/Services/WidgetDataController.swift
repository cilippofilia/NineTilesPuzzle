//
//  WidgetDataController.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/5/26.
//

import Foundation
import WidgetKit

/// Owns every write to the shared `WidgetSnapshot` and the matching home-screen widget
/// reloads. `GameSession` calls in at the few moments widget-visible state actually changes
/// (game start/end/leave/background, daily completion, stats resets) — never per move, so
/// the WidgetKit refresh budget is spent only on real changes.
///
/// Each update rewrites one section of the snapshot and reloads only that section's widget
/// kind, skipping the reload entirely when the section is unchanged. All methods no-op when
/// `defaults` is `nil` (unit tests, missing App Group) so callers can wire in unconditionally,
/// mirroring `LiveActivityController`.
@MainActor
final class WidgetDataController {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = WidgetDataStore.sharedDefaults) {
        self.defaults = defaults
    }

    /// Rewrites the Daily Challenge section from the store's current facts.
    func updateDaily(from store: DailyChallengeStore) {
        guard defaults != nil else { return }
        var snapshot = WidgetDataStore.load(from: defaults) ?? WidgetSnapshot()
        let daily = WidgetSnapshot.DailyState(
            // Start-of-day so the widget's "same day as the entry date?" check is exact.
            lastCompletedDay: store.lastCompletedDate.map { Calendar.current.startOfDay(for: $0) },
            calendarStreak: store.calendarStreak,
            bestCalendarStreak: store.bestCalendarStreak,
            bestMoves: store.bestMoves,
            bestTime: store.bestTime
        )
        guard snapshot.daily != daily else { return }
        snapshot.daily = daily
        save(snapshot, reloading: WidgetKind.dailyChallenge)
    }

    /// Rebuilds the per-mode stats section from every (grid size, mode) combination the
    /// stats store has data for.
    func updateStats(from store: StatsStore) {
        guard defaults != nil else { return }
        var snapshot = WidgetDataStore.load(from: defaults) ?? WidgetSnapshot()

        var keys = Set(store.personalBestMoves.keys)
        keys.formUnion(store.personalBestTime.keys)
        keys.formUnion(store.personalBestScore.keys)
        keys.formUnion(store.gamesPlayed.keys)
        keys.formUnion(store.currentStreak.keys)
        keys.formUnion(store.allTimeHighStreak.keys)

        // Sorted so the built array is deterministic and the unchanged-section check works.
        let modeStats = keys
            .sorted { ($0.gameMode.rawValue, $0.gridSize) < ($1.gameMode.rawValue, $1.gridSize) }
            .map { key in
                WidgetSnapshot.ModeStats(
                    gameModeRaw: key.gameMode.rawValue,
                    gridSize: key.gridSize,
                    currentStreak: store.currentStreak[key] ?? 0,
                    allTimeHighStreak: store.allTimeHighStreak[key] ?? 0,
                    personalBestMoves: store.personalBestMoves[key],
                    personalBestTime: store.personalBestTime[key],
                    personalBestScore: store.personalBestScore[key],
                    gamesPlayed: store.gamesPlayed[key] ?? 0
                )
            }

        guard snapshot.modeStats != modeStats else { return }
        snapshot.modeStats = modeStats
        save(snapshot, reloading: WidgetKind.streaksRecords)
    }

    /// Rewrites the resume section for an in-progress game. The caller assembles `state`
    /// (its `boardImageName`/`savedAt` are overwritten here); `boardInput` supplies the board
    /// render when there is a picture — `nil` (numbers games) still produces a valid resume
    /// card, just without a thumbnail. Deliberately no unchanged-section check: callers only
    /// fire at start/leave/background, and `elapsedTime` differs on every one of those anyway.
    func updateResume(boardInput: LiveActivityBoardInput?, state: WidgetSnapshot.ResumeState) {
        guard defaults != nil else { return }
        var snapshot = WidgetDataStore.load(from: defaults) ?? WidgetSnapshot()

        let previousImageName = snapshot.resume?.boardImageName
        let imageName = boardInput.flatMap(writeBoardImage)

        var resume = state
        resume.boardImageName = imageName
        resume.savedAt = .now
        snapshot.resume = resume
        save(snapshot, reloading: WidgetKind.resumeGame)

        // Drop the superseded board only after the new snapshot is saved, so the widget
        // never reads a file that's already gone.
        if let previousImageName, previousImageName != imageName {
            removeBoardImage(named: previousImageName)
        }
    }

    /// Clears the resume section and its board image once the game is over (or gone).
    func clearResume() {
        guard defaults != nil else { return }
        var snapshot = WidgetDataStore.load(from: defaults) ?? WidgetSnapshot()
        guard snapshot.resume != nil else { return }

        let imageName = snapshot.resume?.boardImageName
        snapshot.resume = nil
        save(snapshot, reloading: WidgetKind.resumeGame)
        if let imageName { removeBoardImage(named: imageName) }
    }

    /// Launch-time self-heal: brings the daily and stats sections up to date in one pass,
    /// covering any change that happened without its hook firing (fresh install, migration,
    /// a crash between a store write and its sync).
    func syncAll(dailyStore: DailyChallengeStore, statsStore: StatsStore) {
        updateDaily(from: dailyStore)
        updateStats(from: statsStore)
    }

    private func save(_ snapshot: WidgetSnapshot, reloading kind: String) {
        var stamped = snapshot
        stamped.updatedAt = .now
        WidgetDataStore.save(stamped, to: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    /// Composites the board and writes it to a uniquely named file in the shared container.
    /// Fresh UUID names (rather than one stable name) bust WidgetKit's image cache and avoid
    /// read-while-overwrite races; the superseded file is always deleted, so at most one
    /// stale board ever lingers. Same pipeline as `LiveActivityController.writeSnapshot`.
    private func writeBoardImage(_ input: LiveActivityBoardInput) -> String? {
        guard let data = PuzzleBoardSnapshot.pngData(
            placements: input.placements,
            images: input.tileImages,
            gridSize: input.gridSize,
            blankTileID: input.blankTileID
        ) else { return nil }

        guard let container = LiveActivityStore.containerURL else { return nil }
        let name = "widget-board-\(UUID().uuidString).png"
        do {
            // Same file-protection reasoning as the Live Activity snapshots: the Home Screen
            // renders widgets while locked, so `.complete` protection would blank the board.
            try data.write(to: container.appending(path: name),
                           options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return name
        } catch {
            return nil
        }
    }

    private func removeBoardImage(named name: String) {
        guard let url = LiveActivityStore.boardImageURL(named: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
