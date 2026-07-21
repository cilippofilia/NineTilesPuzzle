//
//  MenuView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI
import UIKit

struct MenuView: View {
    @Environment(GameSession.self) private var session
    @Environment(DailyChallengeStore.self) private var dailyChallengeStore
    @Environment(StoreManager.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var path: [GameRoute] = []
    @State private var showSettings = false
    @State private var showTipsAlert = false
    @State private var showQuickSnapCamera = false
    @State private var paywallContext: PaywallContext?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack {
                    Spacer()

                    BrandMarkView()
                        .padding()

                    DailyChallengeCardView(
                        onPlay: {
                            session.enterDailyMode()
                            beginGame(session: session, path: $path)
                        },
                        onShowCalendar: {
                            if PremiumFeature.dailyArchive.isLocked(isPremiumUnlocked: store.isPremiumUnlocked) {
                                paywallContext = .dailyArchive
                            } else {
                                path.append(.dailyCalendar)
                            }
                        }
                    )
                    .padding([.horizontal, .bottom])

                    MenuOptionsCardView(path: $path)

                    Button {
                        // Quick Snap needs the camera capture step before there's an image to
                        // play with, so it opens the capture sheet instead of pushing the puzzle.
                        if session.mediaSourceType == .camera {
                            showQuickSnapCamera = true
                        } else {
                            beginGame(session: session, path: $path)
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
                            beginGame(session: session, path: $path)
                        },
                        onCancel: { showQuickSnapCamera = false }
                    )
                }
                .navigationDestination(for: GameRoute.self) { route in
                    MenuRouteDestinationView(route: route, path: $path)
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
                .handlingOpenedChallengeFiles { challenge in
                    if path.last == .game { path.removeLast() }
                    session.enterChallengeMode(with: challenge)
                    beginGame(session: session, path: $path)
                }
                .paywallSheet(context: $paywallContext)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppBackgroundView())
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
                beginGame(session: session, path: $path)
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
            case .paywall:
                paywallContext = .general
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
    let challenges = ChallengeStore()
    MenuView()
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: daily, powerUpStore: powerUps, challengeStore: challenges))
        .environment(stats)
        .environment(settings)
        .environment(achievements)
        .environment(daily)
        .environment(powerUps)
        .environment(challenges)
        .environment(StoreManager())
}
