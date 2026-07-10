//
//  AchievementsStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation

@MainActor
@Observable
final class AchievementsStore {
    /// The one achievement that isn't evaluated generically: "unlock every other
    /// achievement" depends on the achievements list itself, not on `StatsStore`, and —
    /// unlike every other achievement — must be allowed to *re-lock* if a future app update
    /// adds new achievements the player hasn't earned yet. `updateCompletionistAchievement`
    /// handles both directions; the generic loop in `checkAchievements` skips this id.
    private static let completionistId = "completionist"

    private let defaults: PersistenceStore

    var achievements: [Achievement] = []
    var newlyUnlockedAchievement: Achievement?

    /// Number of unlocked achievements. Exposed here so views can show the "x / y" tally
    /// without re-running `filter(\.isUnlocked)` in their body on every render.
    var unlockedCount: Int { achievements.count(where: \.isUnlocked) }

    /// Achievements grouped by category — computed in one O(n) pass instead of the view
    /// filtering the whole array once per category (O(categories × n)) on every render.
    var achievementsByCategory: [AchievementCategory: [Achievement]] {
        Dictionary(grouping: achievements, by: \.category)
    }

    init(defaults: PersistenceStore = UserDefaults.standard) {
        self.defaults = defaults
        loadAchievements()
    }

    func refreshAchievementsFromRemote() async {
        guard let definitions = try? await AchievementService.fetchRemote() else { return }
        achievements = definitions.map(hydrated)
    }

    /// Re-evaluates every achievement's metric against current `stats` and unlocks any that
    /// newly qualify. `justSolved` and `now` only matter to the handful of metrics that read
    /// them (e.g. time-of-day solves) — every other metric ignores them. `challengeStore` is
    /// optional, read only by the three Challenge Friends metrics.
    func checkAchievements(
        using stats: StatsStore, challengeStore: ChallengeStore? = nil, justSolved: Bool = false, now: Date = Date()
    ) {
        for i in achievements.indices {
            guard achievements[i].id != Self.completionistId else { continue }
            guard !achievements[i].isUnlocked else { continue }

            let value = achievements[i].metric.value(in: stats, challengeStore: challengeStore, justSolved: justSolved, now: now)
            guard achievements[i].comparison.isSatisfied(value: value, target: achievements[i].target) else { continue }

            unlock(at: i, now: now)
        }

        updateCompletionistAchievement(now: now)
    }

    func dismissAchievementNotification() async {
        newlyUnlockedAchievement = nil
    }
}

private extension AchievementsStore {
    enum Keys {
        static func achievement(id: String) -> String { "puzzle.achievement.\(id)" }
        static func achievementDate(id: String) -> String { "puzzle.achievementDate.\(id)" }
    }

    func loadAchievements() {
        let definitions = AchievementService.loadCached() ?? AchievementService.loadBundle()
        achievements = definitions.map(hydrated)
    }

    /// Applies persisted unlock state to a freshly-loaded/fetched `Achievement` definition.
    func hydrated(_ achievement: Achievement) -> Achievement {
        var a = achievement
        a.isUnlocked = defaults.bool(forKey: Keys.achievement(id: achievement.id))
        if a.isUnlocked {
            let date = defaults.double(forKey: Keys.achievementDate(id: achievement.id))
            a.unlockedDate = date > 0 ? Date(timeIntervalSinceReferenceDate: date) : nil
        }
        return a
    }

    func unlock(at index: Int, now: Date) {
        achievements[index].isUnlocked = true
        achievements[index].unlockedDate = now
        defaults.set(true, forKey: Keys.achievement(id: achievements[index].id))
        defaults.set(now.timeIntervalSinceReferenceDate, forKey: Keys.achievementDate(id: achievements[index].id))
        if newlyUnlockedAchievement == nil {
            newlyUnlockedAchievement = achievements[index]
        }
    }

    func revoke(at index: Int) {
        achievements[index].isUnlocked = false
        achievements[index].unlockedDate = nil
        defaults.set(false, forKey: Keys.achievement(id: achievements[index].id))
        defaults.removeObject(forKey: Keys.achievementDate(id: achievements[index].id))
    }

    /// Unlocks Completionist once every other achievement is unlocked, and revokes it the
    /// moment that's no longer true — e.g. right after an app update introduces a new
    /// achievement the player hasn't earned yet. Runs after the generic loop above so an
    /// achievement unlocked in this same pass already counts toward completion.
    func updateCompletionistAchievement(now: Date) {
        guard let index = achievements.firstIndex(where: { $0.id == Self.completionistId }) else { return }
        let others = achievements.indices.filter { $0 != index }
        let allOthersUnlocked = !others.isEmpty && others.allSatisfy { achievements[$0].isUnlocked }

        if allOthersUnlocked && !achievements[index].isUnlocked {
            unlock(at: index, now: now)
        } else if !allOthersUnlocked && achievements[index].isUnlocked {
            revoke(at: index)
        }
    }
}
