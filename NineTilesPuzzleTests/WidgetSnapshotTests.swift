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
            isPremiumUnlocked: true,
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
        // A snapshot written before any daily was ever completed — the optional section
        // absent must decode cleanly rather than failing the whole read.
        let json = Data(#"{"updatedAt":800000000}"#.utf8)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        #expect(decoded.daily == nil)
    }

    @Test func decodesMissingEntitlementFieldAsLocked() throws {
        // A snapshot written by the app before the paywall shipped has no
        // `isPremiumUnlocked` key at all — it must decode as locked, not crash or
        // accidentally unlock every widget.
        let json = Data(#"{"updatedAt":800000000}"#.utf8)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        #expect(decoded.isPremiumUnlocked == false)
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
