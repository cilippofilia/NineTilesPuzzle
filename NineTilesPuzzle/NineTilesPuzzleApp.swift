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
    @State private var gameSession: GameSession
    @State private var soundService = SoundService()
    @State private var gameCenterService = GameCenterService()
    @State private var showSplash = true

    init() {
        let statsStore = StatsStore()
        let settingsStore = SettingsStore()
        let achievementsStore = AchievementsStore()
        _statsStore = State(initialValue: statsStore)
        _settingsStore = State(initialValue: settingsStore)
        _achievementsStore = State(initialValue: achievementsStore)
        _gameSession = State(initialValue: GameSession(
            statsStore: statsStore,
            achievementsStore: achievementsStore,
            settingsStore: settingsStore
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
                    .environment(soundService)
                    .environment(gameCenterService)

                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .task { gameCenterService.authenticate() }
        }
    }
}
