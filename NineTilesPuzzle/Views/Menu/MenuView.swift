//
//  MenuView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import Billboard
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
    @State private var interstitialAd: BillboardAd?
    @State private var bannerAd: BillboardAd?

    /// Points at a personal cross-promo feed (github.com/cilippofilia/cross-promo-ads) instead
    /// of Billboard's default shared community feed, so only Filippo Cilia's own apps show up.
    /// "6776386637" is this app's own Apple ID (ASC app resource id, same number as the App
    /// Store URL) — excluded so Billboard never advertises this app to its own free players.
    private let billboardConfiguration = BillboardConfiguration(
        adsJSONURL: URL(string: "https://raw.githubusercontent.com/cilippofilia/cross-promo-ads/main/ads.json"),
        excludedIDs: ["6776386637"]
    )

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
                // A Billboard cross-promo ad every 3rd solved game (see the `.onChange` below) —
                // whether that's landing back on the menu or chaining another "Continue" without
                // ever leaving `PuzzleView` (a `.fullScreenCover` presents over the whole window
                // regardless of nav-stack depth). Never mid-game or on a quit (see
                // `completedGameSignal`'s doc comment on `GameSession`). Fetched directly (rather
                // than via Billboard's own `.showBillboard(when:)`) so a failed fetch can't get
                // the trigger stuck: that helper re-fetches only on a false→true edge of its
                // `Binding<Bool>`, which never resets to false when a fetch comes back empty,
                // silently disabling every future interstitial for the rest of the app session.
                // `.fullScreenCover(item:)` has no such trap — SwiftUI always resets
                // `interstitialAd` to nil on dismiss, so the next eligible completion always gets
                // a fresh attempt regardless of whether the last one found an ad.
                .fullScreenCover(item: $interstitialAd) { ad in
                    BillboardView(advert: ad, config: billboardConfiguration) {
                        PaywallView(context: .removeAds)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppBackgroundView())
            // A persistent ambient banner for free players, refreshed each time they return to
            // the menu — separate from the one-shot post-solve interstitial above. Hides itself
            // instantly (no lingering dismiss animation) the moment premium unlocks mid-session.
            .safeAreaInset(edge: .bottom) {
                if !store.isPremiumUnlocked, let bannerAd {
                    BillboardBannerView(advert: bannerAd, config: billboardConfiguration, hideDismissButtonAndTimer: true)
                        .overlay(alignment: .topTrailing) {
                            Button("Remove Ads", systemImage: "xmark") {
                                paywallContext = .removeAds
                            }
                            .labelStyle(.iconOnly)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.45), in: .circle)
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                        .padding()
                }
            }
            .task { await refreshBannerAd() }
            .onChange(of: session.completedGameSignal) { _, newValue in
                Task { await refreshBannerAd() }
                // Every 3rd solved game, not every one — including consecutive "Continue" rounds,
                // not just returns to the menu (see `completedGameSignal`). A full-screen
                // interruption every single game would be a lot more daunting than the ambient
                // bottom banner.
                guard !store.isPremiumUnlocked, newValue.isMultiple(of: 3) else { return }
                Task { await refreshInterstitialAd() }
            }
            .onChange(of: store.isPremiumUnlocked) { _, unlocked in
                if unlocked { bannerAd = nil }
            }
        }
    }

    /// Picks a fresh bottom-banner ad for free players — called on first appear and again every
    /// time `completedGameSignal` bumps, so the banner doesn't show the same promo for the
    /// entire app session. No-ops (leaving whatever's already showing) for premium players or if
    /// the fetch fails; a failed fetch surfaces no error since a missing banner is a non-event.
    private func refreshBannerAd() async {
        guard !store.isPremiumUnlocked, let url = billboardConfiguration.adsJSONURL else { return }
        bannerAd = try? await BillboardViewModel.fetchRandomAd(from: url, excludedIDs: billboardConfiguration.excludedIDs)
    }

    /// Fetches the single post-solve interstitial ad — see the doc comment at this view's
    /// `.fullScreenCover(item: $interstitialAd)` for why this is a direct fetch rather than
    /// Billboard's own `.showBillboard(when:)` helper.
    private func refreshInterstitialAd() async {
        guard let url = billboardConfiguration.adsJSONURL else { return }
        interstitialAd = try? await BillboardViewModel.fetchRandomAd(from: url, excludedIDs: billboardConfiguration.excludedIDs)
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
