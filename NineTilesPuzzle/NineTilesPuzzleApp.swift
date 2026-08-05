//
//  NineTilesPuzzleApp.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@main
struct NineTilesPuzzleApp: App {
    @State private var statsStore: StatsStore
    @State private var settingsStore: SettingsStore
    @State private var achievementsStore: AchievementsStore
    @State private var dailyChallengeStore: DailyChallengeStore
    @State private var powerUpStore: PowerUpStore
    @State private var challengeStore: ChallengeStore
    @State private var storeManager: StoreManager
    @State private var gameSession: GameSession
    @State private var soundService: SoundService
    @State private var gameCenterService = GameCenterService()
    @State private var wallOfFameStore = WallOfFameStore()
    @State private var motionManager = MotionManager()
    @State private var dailyReminderService = DailyReminderService()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let statsStore = StatsStore()
        let settingsStore = SettingsStore()
        let achievementsStore = AchievementsStore()
        let dailyChallengeStore = DailyChallengeStore()
        let powerUpStore = PowerUpStore()
        let challengeStore = ChallengeStore()
        let storeManager = StoreManager(
            debugOverride: { settingsStore.debugForcePremiumUnlocked },
            debugForceRemoved: { settingsStore.debugForcePremiumRemoved }
        )
        _statsStore = State(initialValue: statsStore)
        _settingsStore = State(initialValue: settingsStore)
        _achievementsStore = State(initialValue: achievementsStore)
        _dailyChallengeStore = State(initialValue: dailyChallengeStore)
        _powerUpStore = State(initialValue: powerUpStore)
        _challengeStore = State(initialValue: challengeStore)
        _storeManager = State(initialValue: storeManager)
        _soundService = State(initialValue: SoundService(volumeScale: { settingsStore.feedbackIntensity.scale }))
        _gameSession = State(initialValue: GameSession(
            statsStore: statsStore,
            achievementsStore: achievementsStore,
            settingsStore: settingsStore,
            dailyChallengeStore: dailyChallengeStore,
            powerUpStore: powerUpStore,
            challengeStore: challengeStore,
            isPremiumUnlocked: { storeManager.isPremiumUnlocked }
        ))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MenuView()
                    .environment(gameSession)
                    .environment(statsStore)
                    .environment(settingsStore)
                    .environment(achievementsStore)
                    .environment(dailyChallengeStore)
                    .environment(powerUpStore)
                    .environment(challengeStore)
                    .environment(storeManager)
                    .environment(soundService)
                    .environment(gameCenterService)
                    .environment(wallOfFameStore)
                    .environment(motionManager)
                    .environment(dailyReminderService)
                    .overlay(alignment: .top) {
                        HiddenBrandMarkView()
                    }

                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .task { gameCenterService.authenticate() }
            .task { await refreshNotifications() }
            .task { await storeManager.start() }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await refreshNotifications() }
            }
        }
    }

    /// Re-syncs every pending notification with the current authorization/settings state —
    /// needed on launch and every foreground, since the player may have changed notification
    /// permission from the system Settings app, or a day may have rolled over while the app
    /// was backgrounded. The streak-milestone celebration isn't included here — it's fired
    /// immediately at solve time instead of scheduled ahead.
    private func refreshNotifications() async {
        await dailyReminderService.refreshAuthorizationStatus()
        let completedToday = dailyChallengeStore.isDailyCompletedToday
        dailyReminderService.rescheduleIfNeeded(
            enabled: settingsStore.dailyReminderEnabled,
            time: settingsStore.dailyReminderTime,
            completedToday: completedToday
        )
        dailyReminderService.rescheduleNewChallengeAvailableIfNeeded(
            enabled: settingsStore.newChallengeAvailableEnabled,
            time: settingsStore.newChallengeAvailableTime
        )
        dailyReminderService.rescheduleStreakAtRiskIfNeeded(
            enabled: settingsStore.streakAtRiskEnabled,
            calendarStreak: dailyChallengeStore.calendarStreak,
            completedToday: completedToday
        )
        dailyReminderService.rescheduleWeeklyRecapIfNeeded(
            enabled: settingsStore.weeklyRecapEnabled,
            completedDaysThisWeek: dailyChallengeStore.completedDaysInTrailingWeek(),
            calendarStreak: dailyChallengeStore.calendarStreak
        )
    }
}
