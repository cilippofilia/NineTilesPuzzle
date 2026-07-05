//
//  WidgetSnapshotTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/5/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("WidgetSnapshot")
struct WidgetSnapshotTests {
    private func makeFullSnapshot() -> WidgetSnapshot {
        WidgetSnapshot(
            daily: WidgetSnapshot.DailyState(
                lastCompletedDay: Calendar.current.startOfDay(for: .now),
                calendarStreak: 6,
                bestCalendarStreak: 14,
                bestMoves: 32,
                bestTime: 118
            ),
            modeStats: [
                WidgetSnapshot.ModeStats(
                    gameModeRaw: GameMode.slide.rawValue,
                    gridSize: 4,
                    currentStreak: 3,
                    allTimeHighStreak: 9,
                    personalBestMoves: 41,
                    personalBestTime: 133,
                    personalBestScore: nil,
                    gamesPlayed: 27
                ),
                WidgetSnapshot.ModeStats(
                    gameModeRaw: GameMode.timeTrial.rawValue,
                    gridSize: 5,
                    personalBestScore: 1240,
                    gamesPlayed: 8
                )
            ],
            resume: WidgetSnapshot.ResumeState(
                boardImageName: "widget-board-test.png",
                gameModeRaw: GameMode.swap.rawValue,
                displayTitle: "Daily Challenge",
                displayIcon: "calendar",
                gridSize: 5,
                moveCount: 17,
                elapsedTime: 92,
                progress: 0.44,
                savedAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
            ),
            updatedAt: Date(timeIntervalSinceReferenceDate: 800_000_100)
        )
    }

    @Test func roundTripsThroughJSON() throws {
        let snapshot = makeFullSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @Test func decodesWithoutOptionalSections() throws {
        // A snapshot written before a game was ever played or a daily completed — both
        // optional sections absent must decode cleanly rather than failing the whole read.
        let json = Data(#"{"modeStats":[],"updatedAt":800000000}"#.utf8)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        #expect(decoded.daily == nil)
        #expect(decoded.resume == nil)
        #expect(decoded.modeStats.isEmpty)
    }

    @Test func savesAndLoadsThroughDefaultsSuite() throws {
        let suiteName = "widget-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(WidgetDataStore.load(from: defaults) == nil)

        let snapshot = makeFullSnapshot()
        WidgetDataStore.save(snapshot, to: defaults)
        #expect(WidgetDataStore.load(from: defaults) == snapshot)
    }

    @Test func loadReturnsNilForCorruptData() throws {
        let suiteName = "widget-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("not json".utf8), forKey: WidgetDataStore.snapshotKey)
        #expect(WidgetDataStore.load(from: defaults) == nil)
    }
}
