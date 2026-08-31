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
            bestTime: store.bestTime,
            frozenDay: store.mostRecentFrozenDate.map { Calendar.current.startOfDay(for: $0) }
        )
        guard snapshot.daily != daily else { return }
        snapshot.daily = daily
        save(snapshot, reloading: [WidgetKind.dailyChallenge])
    }

    /// Launch-time self-heal: brings the daily section up to date, covering any change that
    /// happened without its hook firing (fresh install, migration, a crash between a store
    /// write and its sync).
    func syncAll(dailyStore: DailyChallengeStore, statsStore: StatsStore) {
        updateDaily(from: dailyStore)
    }

    /// Rewrites the entitlement flag locked/unlocked widget UI reads, reloading only when it
    /// actually changed.
    func updateEntitlement(isPremiumUnlocked: Bool) {
        guard defaults != nil else { return }
        var snapshot = WidgetDataStore.load(from: defaults) ?? WidgetSnapshot()
        guard snapshot.isPremiumUnlocked != isPremiumUnlocked else { return }
        snapshot.isPremiumUnlocked = isPremiumUnlocked
        save(snapshot, reloading: [WidgetKind.dailyChallenge])
    }

    private func save(_ snapshot: WidgetSnapshot, reloading kinds: [String]) {
        var stamped = snapshot
        stamped.updatedAt = .now
        WidgetDataStore.save(stamped, to: defaults)
        for kind in kinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
