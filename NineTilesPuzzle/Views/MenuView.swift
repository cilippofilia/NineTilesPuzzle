//
//  MenuView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI
import UIKit

enum GameRoute: Hashable {
    case game
    case gridSizePicker
    case achievements
    case wallOfFame
    case gameModes
    case mediaPicker
    case dailyCalendar
}

struct MenuView: View {
    @Environment(GameSession.self) private var session
    @Environment(AchievementsStore.self) private var achievementsStore
    @Environment(DailyChallengeStore.self) private var dailyChallengeStore
    @Environment(\.openURL) private var openURL
    @State private var path: [GameRoute] = []
    @State private var showSettings = false
    @State private var showTipsAlert = false
    @State private var showQuickSnapCamera = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Spacer()

                BrandMarkView()
                    .padding()

                DailyChallengeCardView(
                    onPlay: {
                        session.enterDailyMode()
                        session.tiles = []
                        session.isLoading = true
                        path.append(.game)
                    },
                    onShowCalendar: {
                        path.append(.dailyCalendar)
                    }
                )
                .padding([.horizontal, .bottom])

                VStack(spacing: 0) {
                    if session.selectedGameMode != .zen {
                        MenuStatsCardView()
                            .frame(height: 55)

                        Divider()
                    }

                    Button {
                        path.append(.gameModes)
                    } label: {
                        HStack {
                            Label("Game Mode", systemImage: "gamecontroller")
                            Spacer()
                            Text(session.selectedGameMode.title)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .contentShape(.rect)
                    }
                    .foregroundStyle(.primary)

                    Divider()

                    Button {
                        path.append(.mediaPicker)
                    } label: {
                        HStack {
                            Label("Media", systemImage: "photo.tv")
                            Spacer()
                            Text(session.mediaSourceType.label)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .contentShape(.rect)
                    }
                    .foregroundStyle(.primary)

                    Divider()

                    Button {
                        guard !session.isGauntletLadderMode else { return }
                        path.append(.gridSizePicker)
                    } label: {
                        HStack {
                            Label("Grid Size", systemImage: "square.grid.3x3.square")
                            Spacer()
                            Text(session.isGauntletLadderMode
                                 ? "Stage \(session.currentLadderStage) of \(GauntletLadderRules.stageCount)"
                                 : session.difficultyDisplayValue)
                                .foregroundStyle(.secondary)
                            if !session.isGauntletLadderMode {
                                Image(systemName: "chevron.forward")
                                    .imageScale(.small)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .contentShape(.rect)
                    }
                    .foregroundStyle(session.isGauntletLadderMode ? .secondary : .primary)
                    .disabled(session.isGauntletLadderMode)

                    Divider()

                    Button {
                        path.append(.achievements)
                    } label: {
                        HStack {
                            Label("Achievements", systemImage: "trophy.fill")
                            Spacer()
                            Text("\(achievementsStore.unlockedCount)/\(achievementsStore.achievements.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .contentShape(.rect)
                    }
                    .foregroundStyle(.primary)

                    Divider()

                    Button {
                        path.append(.wallOfFame)
                    } label: {
                        HStack {
                            Label("Wall of Fame", systemImage: "photo.artframe")
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .contentShape(.rect)
                    }
                    .foregroundStyle(.primary)
                }
                .background(.quaternary, in: .rect(cornerRadius: 20))
                .padding(.horizontal)

                Button {
                    // Quick Snap needs the camera capture step before there's an image to
                    // play with, so it opens the capture sheet instead of pushing the puzzle.
                    if session.mediaSourceType == .camera {
                        showQuickSnapCamera = true
                    } else {
                        session.tiles = []
                        session.isLoading = true
                        path.append(.game)
                    }
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .contentShape(.rect(cornerRadius: 20))
                }
                .foregroundStyle(.white)
                .background(.blue, in: .rect(cornerRadius: 20))
                .padding()

                Spacer()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showQuickSnapCamera) {
                QuickSnapCameraView(
                    shotDuration: session.currentQuickSnapDuration,
                    onCapture: { image in
                        showQuickSnapCamera = false
                        session.enterQuickSnapMode(with: image)
                        session.tiles = []
                        session.isLoading = true
                        path.append(.game)
                    },
                    onCancel: { showQuickSnapCamera = false }
                )
            }
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .game:
                    PuzzleView()
                case .gridSizePicker:
                    GridSizePickerView()
                case .achievements:
                    AchievementsView()
                case .wallOfFame:
                    WallOfFameView()
                case .gameModes:
                    GameModeView()
                case .mediaPicker:
                    MediaSourcePickerView()
                case .dailyCalendar:
                    DailyChallengeCalendarView { day in
                        session.enterDailyMode(for: day)
                        session.tiles = []
                        session.isLoading = true
                        path.append(.game)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape.fill") {
                        showSettings = true
                    }
                    .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tips", systemImage: "lightbulb.max") {
                        showTipsAlert = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .alert("Quick Tip", isPresented: $showTipsAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Got It", role: .cancel) { }
            } message: {
                Text("For a curated experience with your own photos, create a dedicated album in the Photos app with only the images you'd like to use as puzzles, then grant Nine Tiles access to that album only.")
            }
            .onOpenURL { url in
                guard let link = DeepLink(url: url) else { return }
                handleDeepLink(link)
            }
        }
    }

    /// Routes a widget deep link to its destination, dismissing any covering sheets so the
    /// destination is actually visible.
    ///
    /// When a game is already on screen, two cases keep it running untouched (resume, and
    /// daily while already playing today's daily). Every other route pops to the menu first
    /// and then waits out the pop transition — the popped `PuzzleView`'s `onDisappear` runs
    /// `leaveGame()` (the same persistence path as quitting by hand), which also resets the
    /// daily/Quick Snap session flags, so applying the new route before it completes would
    /// let that teardown clobber the route's setup.
    private func handleDeepLink(_ link: DeepLink) {
        showSettings = false
        showTipsAlert = false
        showQuickSnapCamera = false

        let wasInGame = path.last == .game
        if wasInGame {
            switch link {
            case .resume where session.hasResumableGame:
                // Tapping "resume" while playing means keep playing.
                return
            case .daily where session.isDailyGameActive && !session.isReplayingPastDaily && !dailyChallengeStore.isDailyCompletedToday:
                // Already mid-way through today's daily — keep playing it. A history
                // replay doesn't count: the link means today's challenge, so fall
                // through to the pop-and-restart path below.
                return
            default:
                path = []
            }
        }

        Task {
            if wasInGame {
                // Long enough for the pop transition's onDisappear → leaveGame() to land.
                try? await Task.sleep(for: .milliseconds(600))
            }
            switch link {
            case .daily:
                // Already done today: the menu's daily card shows the completed state.
                guard !dailyChallengeStore.isDailyCompletedToday else { return }
                session.enterDailyMode()
                session.tiles = []
                session.isLoading = true
                path.append(.game)
            case .resume:
                // Flag first, so PuzzleView's onAppear sees it before wiping the board.
                // With nothing to resume, landing on the menu is the whole route.
                guard session.hasResumableGame else { return }
                session.requestResume()
                path.append(.game)
            case .mode(let mode, let gridSize):
                // Land on the configured menu rather than auto-starting: play is gated by
                // mode specifics (Quick Snap capture, ladder stages), and the menu handles
                // all of them.
                session.setGameMode(mode)
                if let gridSize {
                    session.setGridSize(gridSize)
                }
            }
        }
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    let daily = DailyChallengeStore()
    let powerUps = PowerUpStore()
    MenuView()
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: daily, powerUpStore: powerUps))
        .environment(stats)
        .environment(settings)
        .environment(achievements)
        .environment(daily)
        .environment(powerUps)
}
