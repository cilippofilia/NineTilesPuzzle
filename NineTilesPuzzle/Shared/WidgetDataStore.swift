//
//  WidgetDataStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/5/26.
//

import Foundation

/// A single JSON snapshot of everything the home-screen widgets display, written by the app
/// into the shared App Group defaults and read back by the widget extension. Every section is
/// optional so older extensions keep decoding newer snapshots (and vice versa) as fields grow.
///
/// Shared between the app and the widget extension: this file must be a member of both targets.
/// `nonisolated` (like everything in this file) so its Codable conformance is usable from
/// nonisolated contexts despite the app target's default MainActor isolation.
nonisolated struct WidgetSnapshot: Codable, Hashable {
    /// Daily Challenge completion and calendar-streak facts. Today's grid size and mode are
    /// deliberately absent — the widget derives them from `DailyChallengeSeeder` so the
    /// midnight rollover needs no app involvement.
    var daily: DailyState?

    /// One entry per (game mode, grid size) combination the player has touched.
    var modeStats: [ModeStats] = []

    /// The in-progress game, or `nil` when there is nothing to resume.
    var resume: ResumeState?

    var updatedAt: Date = .now

    struct DailyState: Codable, Hashable {
        /// Start-of-day of the last daily completion. The widget compares this against the
        /// entry date, so "done today" flips off at midnight without a new snapshot.
        var lastCompletedDay: Date?
        var calendarStreak = 0
        var bestCalendarStreak = 0
        var bestMoves: Int?
        var bestTime: TimeInterval?
    }

    struct ModeStats: Codable, Hashable {
        var gameModeRaw: String
        var gridSize: Int
        var currentStreak = 0
        var allTimeHighStreak = 0
        var personalBestMoves: Int?
        var personalBestTime: TimeInterval?
        var personalBestScore: Int?
        var gamesPlayed = 0
    }

    struct ResumeState: Codable, Hashable {
        /// Board snapshot PNG filename inside the App Group container, or `nil` for numbers
        /// games which have no picture.
        var boardImageName: String?
        var gameModeRaw: String
        var displayTitle: String
        var displayIcon: String
        var gridSize: Int
        var moveCount: Int
        var elapsedTime: TimeInterval
        var progress: Double
        var savedAt: Date
    }
}

/// Reads and writes the `WidgetSnapshot` through the shared App Group defaults. All accessors
/// no-op (return `nil`) when the App Group isn't available, e.g. in unit tests.
///
/// `nonisolated` because the app target defaults to MainActor isolation but callers reference
/// these statics from nonisolated contexts (default arguments, the widget extension).
nonisolated enum WidgetDataStore {
    static let snapshotKey = "widget.snapshot"

    /// The App Group defaults suite both processes share, or `nil` when the capability is
    /// missing (unit tests, misconfigured entitlements).
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: LiveActivityStore.appGroupID)
    }

    static func load(from defaults: UserDefaults? = WidgetDataStore.sharedDefaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = WidgetDataStore.sharedDefaults) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}

/// Widget kind identifiers — the contract between each widget's configuration and the app's
/// scoped `WidgetCenter.reloadTimelines(ofKind:)` calls.
nonisolated enum WidgetKind {
    static let dailyChallenge = "DailyChallengeWidget"
    static let streaksRecords = "StreaksRecordsWidget"
    static let resumeGame = "ResumeGameWidget"
}
