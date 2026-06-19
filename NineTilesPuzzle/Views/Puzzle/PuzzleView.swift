//
//  PuzzleView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleView: View {
    @Environment(GameSession.self) private var session
    @Environment(SettingsStore.self) private var settings
    @Environment(AchievementsStore.self) private var achievementsStore
    @Environment(SoundService.self) private var soundService
    @Environment(\.dismiss) private var dismiss
    @State private var showCompletion = false
    @State private var showNewRecord = false
    @State private var showNewMovesRecord = false
    @State private var showNewBestTime = false
    @State private var showQuitAlert = false
    @State private var bannerOffset: CGSize = .zero
    @State private var isSolving = false
    @State private var zenBreathScale: CGFloat = 1
    @State private var zenGlowOpacity: Double = 0
    @State private var zenSparkles = ZenSparkle.makeCluster()

    var body: some View {
        ZStack {
            // Layer 1: centered main content — only Spacer/content/Spacer so centering
            // is never affected by supplementary elements in other layers
            VStack {
                if session.isLoading {
                    LoadingView()
                        .transition(.opacity)
                } else if session.isPreviewing, let image = session.sourceImage {
                    ImagePreviewView(image: image, onSkip: session.skipPreview)
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                } else if let error = session.error {
                    PuzzleErrorView(error: error, onRetry: startNewGame)
                        .transition(.opacity)
                } else {
                    Spacer()
                    PuzzleGridView(showReveal: showCompletion)
                        .clipShape(.rect(cornerRadius: 12))
                        // Zen mode's only acknowledgment that a puzzle is done: the finished
                        // picture takes one slow, soft breath, with a little magic dust
                        // drifting around its edge, before the next one quietly arrives.
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(colors: [.teal, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 4
                                )
                                .blur(radius: 7)
                                .opacity(session.isZenMode ? zenGlowOpacity : 0)
                        }
                        .overlay {
                            GeometryReader { proxy in
                                ForEach(zenSparkles) { sparkle in
                                    ZenSparkleView(size: sparkle.size, color: sparkle.color, delay: sparkle.delay)
                                        .position(x: sparkle.x * proxy.size.width, y: sparkle.y * proxy.size.height)
                                }
                            }
                            .opacity(session.isZenMode ? zenGlowOpacity : 0)
                            .allowsHitTesting(false)
                        }
                        .shadow(color: .teal.opacity(session.isZenMode ? zenGlowOpacity * 0.7 : 0), radius: 28)
                        .scaleEffect(session.isZenMode ? zenBreathScale : 1)
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .identity
                        ))
                    Spacer()
                }
            }
            .animation(.easeInOut(duration: 0.35), value: session.isLoading)
            .animation(.easeInOut(duration: 0.35), value: session.isPreviewing)

            // Layer 2: streak counter + move counter float at top — outside layout flow so
            // they don't shift the grid's vertical center. Hidden entirely in Zen mode, which
            // shows nothing but the puzzle itself.
            if !session.isZenMode {
                VStack {
                    PuzzleStatusBarView(
                        gameMode: session.selectedGameMode,
                        debugOverlayEnabled: settings.debugOverlayEnabled,
                        currentStreak: session.currentStreakForCurrentSize,
                        bestStreak: session.allTimeHighStreakForCurrentSize,
                        timerRemaining: session.timerRemaining,
                        isTimerRunning: session.isTimerRunning,
                        moveCount: session.currentMoveCount,
                        personalBest: session.personalBestForCurrentSize,
                        elapsedTime: session.elapsedTime,
                        personalBestTime: session.personalBestTimeForCurrentSize
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    .opacity(streakVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: session.isLoading)
                    .animation(.easeInOut(duration: 0.35), value: session.isPreviewing)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showCompletion)
                    Spacer()
                }
            }

            // Layer 3: completion overlay. Skipped in Zen mode — the solved picture reveal
            // (in PuzzleGridView) is the only feedback; the next puzzle starts on its own.
            if !session.isZenMode {
                VStack {
                    CompletionBannerView(gameMode: session.selectedGameMode, streak: session.currentStreakForCurrentSize, isNewRecord: showNewRecord, moveCount: session.currentMoveCount, personalBest: session.personalBestForCurrentSize, elapsedTime: session.elapsedTime, personalBestTime: session.personalBestTimeForCurrentSize, isPracticeMode: settings.debugOverlayEnabled)
                        .padding(.top)
                        .padding(.horizontal)
                        .offset(x: bannerOffset.width, y: (showCompletion ? 0 : -300) + bannerOffset.height)
                        .opacity(showCompletion ? 1 : 0)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        bannerOffset = value.translation
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        bannerOffset = .zero
                                    }
                                }
                        )

                    // Floats below the banner as its own layer — rather than growing the
                    // banner's card — and slides down out from behind it on appear.
                    if showCompletion && hasNewBestBadge {
                        NewBestBadgesView(
                            showsStreak: session.selectedGameMode != .slide,
                            moveCount: session.currentMoveCount,
                            isNewMovesRecord: showNewMovesRecord,
                            elapsedTime: session.elapsedTime,
                            isNewBestTime: showNewBestTime
                        )
                        .padding(.horizontal)
                        .offset(bannerOffset)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    Button("Continue", action: startNewGame)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.bottom)
                        .offset(y: showCompletion ? 0 : 300)
                        .opacity(showCompletion ? 1 : 0)
                }
                .allowsHitTesting(showCompletion)
            }

            // Layer 4: achievement unlock toast — only shown mid-game to avoid overlapping the
            // completion banner. Achievements aren't tracked in Zen mode, so this never fires there.
            if let achievement = achievementsStore.newlyUnlockedAchievement, !session.isSolved {
                VStack {
                    Spacer()
                    AchievementToastView(achievement: achievement)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: achievementsStore.newlyUnlockedAchievement)
        .task(id: achievementsStore.newlyUnlockedAchievement?.id) {
            guard achievementsStore.newlyUnlockedAchievement != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            await achievementsStore.dismissAchievementNotification()
        }
        .task(id: session.isSolved) {
            guard session.isSolved else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeInOut(duration: 0.35)) {
                showNewRecord = false
                showNewMovesRecord = false
                showNewBestTime = false
            }
        }
        // Zen mode has no completion banner or "Continue" button to tap: the solved picture
        // breathes gently in and out — one inhale, one exhale — and the next puzzle begins
        // the moment it settles, with no further prompt needed.
        .task(id: session.isSolved) {
            guard session.isSolved, session.isZenMode else {
                zenBreathScale = 1
                zenGlowOpacity = 0
                return
            }
            zenSparkles = ZenSparkle.makeCluster()
            withAnimation(.easeInOut(duration: 1.3)) {
                zenBreathScale = 1.025
                zenGlowOpacity = 0.65
            }
            try? await Task.sleep(for: .seconds(1.3))
            guard session.isSolved else { return }
            withAnimation(.easeInOut(duration: 1.1)) {
                zenBreathScale = 1
                zenGlowOpacity = 0
            }
            try? await Task.sleep(for: .seconds(1.1))
            guard session.isSolved else { return }
            startNewGame()
        }
        // `.task` can be delayed in actually starting while the MainActor is busy (e.g. the
        // NavigationStack push transition), leaving the previous game's stale tiles briefly
        // visible and tappable. `.onAppear` runs synchronously, closing that window.
        .onAppear {
            session.tiles = []
            session.isLoading = true
        }
        .task {
            await session.startNewGame()
        }
        .sensoryFeedback(.success, trigger: session.isSolved) { _, newValue in
            newValue && settings.hapticsEnabled
        }
        .sensoryFeedback(.warning, trigger: session.didBreakStreak) { _, _ in
            settings.hapticsEnabled
        }
        .onChange(of: session.isSolved) { _, solved in
            if solved { soundService.playCompletion() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(solved ? 0.3 : 0)) {
                showCompletion = solved
            }
        }
        .onChange(of: session.isNewRecord) { _, isRecord in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showNewRecord = isRecord
            }
        }
        .onChange(of: session.isNewMovesRecord) { _, isRecord in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showNewMovesRecord = isRecord
            }
        }
        .onChange(of: session.isNewBestTime) { _, isRecord in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showNewBestTime = isRecord
            }
        }
        .navigationTitle(session.isZenMode ? "" : "Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isGameActive)
        .toolbar {
            if isGameActive {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        // Zen mode never tracks progress, so there's nothing a quit
                        // confirmation would actually be protecting — leave immediately.
                        if session.isZenMode {
                            session.leaveGame()
                            dismiss()
                        } else {
                            showQuitAlert = true
                        }
                    }
                }
            }

            if showSolveButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Solve", systemImage: "wand.and.stars", action: solvePuzzle)
                        .disabled(isSolving)
                }
            }
        }
        .alert("Quit this run?", isPresented: $showQuitAlert) {
            Button("Quit", role: .destructive) {
                session.leaveGame()
                dismiss()
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("Your progress on this puzzle will be lost.")
        }
        .onDisappear {
            session.leaveGame()
        }
    }

    private var isGameActive: Bool {
        (!session.tiles.isEmpty || session.isPreviewing) && !session.isSolved
    }

    private var showSolveButton: Bool {
        let result = settings.debugOverlayEnabled
            && session.selectedGameMode == .slide
            && !session.tiles.isEmpty
            && !session.isSolved
        return result
    }

    private var streakVisible: Bool {
        !showCompletion && !session.isLoading && session.error == nil
    }

    private var hasNewBestBadge: Bool {
        showNewMovesRecord || (session.selectedGameMode == .slide && showNewBestTime)
    }

    private func startNewGame() {
        bannerOffset = .zero
        Task { await session.startNewGame() }
    }

    /// Debug-only: walks the puzzle to its solved state, one slide at a time, so the slide
    /// mode's win condition and animations can be verified end to end.
    private func solvePuzzle() {
        guard !isSolving else { return }
        isSolving = true

        let moves = SlideSolver().solve(tiles: session.tiles, gridSize: session.gridSize)

        Task {
            for move in moves {
                guard !session.isSolved else {
                    break
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = session.slideTile(from: move)
                }
                soundService.playTileClick()
                try? await Task.sleep(for: .milliseconds(120))
            }
            isSolving = false
        }
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    PuzzleView()
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings))
        .environment(settings)
        .environment(achievements)
        .environment(SoundService())
}
