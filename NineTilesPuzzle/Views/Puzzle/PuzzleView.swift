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
    @Environment(\.scenePhase) private var scenePhase

    @State private var completion = PuzzleCompletionViewModel()
    @State private var showQuitAlert = false
    @State private var isSolving = false
    @State private var showTimeTrialDelta = false
    @State private var newGameTask: Task<Void, Never>?

    var body: some View {
        // Split into two independently type-checked expressions to avoid the compiler's
        // expression complexity limit on long modifier chains.
        let gameView = ZStack {
            // Layer 1: centered main content — only Spacer/content/Spacer so centering
            // is never affected by supplementary elements in other layers.
            PuzzleMainContentLayer(
                completion: completion,
                startNewGame: startNewGame,
                switchToPhotosAndRetry: switchToPhotosAndRetry
            )

            // Layers 2 & 3: floating status bar and completion banner. Both are hidden in
            // Zen mode, which shows nothing but the puzzle itself.
            if !session.isZenMode {
                PuzzleStatusOverlayLayer(completion: completion, showTimeTrialDelta: showTimeTrialDelta)
                PuzzleCompletionOverlayView(completion: completion, continueAction: startNewGame)
            }

            // Layer 3b: Time Trial fail overlay — shown instead of the completion banner
            // when the countdown reaches zero unsolved.
            if session.isTimeTrialMode {
                TimeTrialFailOverlay(completion: completion, onTryAgain: startNewGame)
            }

            // Layer 3c: Limited Moves fail overlay — mirrors the Time Trial fail overlay
            // for a spent move budget.
            if session.isLimitedMovesMode {
                LimitedMovesFailOverlay(completion: completion, onTryAgain: startNewGame)
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
            await completion.clearRecordFlagsAfterDelay(isSolved: session.isSolved)
        }
        .task(id: session.isSolved) {
            await completion.runZenCompletionSequence(
                isZenMode: session.isZenMode,
                isSolved: { session.isSolved },
                onComplete: startNewGame
            )
        }
        // Shows the "+1s"/"-2s" combo indicator for each Time Trial move, keyed by move
        // count rather than the delta's value so repeated identical deltas (e.g. two
        // misplays in a row) still restart the fade-out timer.
        .task(id: session.currentMoveCount) {
            guard session.isTimeTrialMode, session.lastTimeTrialDelta != nil else { return }
            showTimeTrialDelta = true
            try? await Task.sleep(for: .seconds(1))
            showTimeTrialDelta = false
        }
        // `.task` can be delayed in actually starting while the MainActor is busy (e.g. the
        // NavigationStack push transition), leaving the previous game's stale tiles briefly
        // visible and tappable. `.onAppear` runs synchronously, closing that window.
        .onAppear {
            session.tiles = []
            session.isLoading = true
        }
        .task {
            if session.isGauntletLadderMode {
                await session.startNewLadderRun()
            } else {
                await session.startNewGame()
            }
        }
        .sensoryFeedback(.success, trigger: session.isSolved) { _, newValue in
            newValue && settings.hapticsEnabled
        }
        .sensoryFeedback(.warning, trigger: session.didBreakStreak) { _, _ in
            settings.hapticsEnabled
        }
        .sensoryFeedback(.error, trigger: session.isTimeTrialFailed) { _, newValue in
            newValue && settings.hapticsEnabled
        }
        .sensoryFeedback(.error, trigger: session.isLimitedMovesFailed) { _, newValue in
            newValue && settings.hapticsEnabled
        }
        .onChange(of: session.isSolved) { _, solved in
            completion.handleSolvedChange(solved, onSolved: soundService.playCompletion)
        }
        // One handler mirrors every per-solve record flag in a single update; see `recordFlags`.
        .onChange(of: recordFlags) { _, flags in
            completion.applyRecords(flags)
        }
        .onChange(of: session.isTimeTrialFailed) { _, failed in
            completion.handleTimeTrialFailedChange(failed)
        }
        .onChange(of: session.isLimitedMovesFailed) { _, failed in
            completion.handleLimitedMovesFailedChange(failed)
        }
        return gameView
        .navigationTitle(session.isDailyGameActive ? "Daily Challenge" : (session.isZenMode ? "" : "Puzzle"))
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

            if completion.showCompletion, let png = solvedPNG {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: png, preview: SharePreview("Solved Puzzle")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                session.pauseTimers()
            } else if newPhase == .active, !session.isLoading, !session.isPreviewing {
                session.resumeTimers()
            }
        }
        .onDisappear {
            session.leaveGame()
        }
    }

    private var solvedPNG: SolvedPuzzleImage? {
        guard let cgImage = session.croppedSourceImage else { return nil }
        let card = ShareCardView(
            image: cgImage,
            gridSize: session.gridSize,
            gameMode: session.selectedGameMode,
            moveCount: session.currentMoveCount,
            elapsedTime: session.elapsedTime,
            isDailyChallenge: session.isDailyGameActive,
            dailyDate: session.dailyEffectiveDate,
            calendarStreak: session.dailyCalendarStreak
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        guard let data = renderer.uiImage?.pngData() else { return nil }
        return SolvedPuzzleImage(pngData: data)
    }

    /// Bundles the session's per-solve record flags so a single `.onChange` can forward them
    /// all to the completion view model at once.
    private var recordFlags: PuzzleRecordFlags {
        PuzzleRecordFlags(
            isNewRecord: session.isNewRecord,
            isNewMovesRecord: session.isNewMovesRecord,
            isNewBestTime: session.isNewBestTime,
            isNewTimeTrialScoreRecord: session.isNewTimeTrialScoreRecord,
            isNewLadderScoreRecord: session.isNewLadderScoreRecord,
            isNewLadderStageRecord: session.isNewLadderStageRecord
        )
    }

    private var isGameActive: Bool {
        (!session.tiles.isEmpty || session.isPreviewing) && !session.isSolved && !session.isTimeTrialFailed && !session.isLimitedMovesFailed
    }

    private var showSolveButton: Bool {
        settings.debugOverlayEnabled
            && session.selectedGameMode == .slide
            && !session.tiles.isEmpty
            && !session.isSolved
    }

    private func startNewGame() {
        newGameTask?.cancel()

        completion.prepareForNewGame()
        // Same reasoning as the `.onAppear` sync clear below: a `Task` body doesn't start
        // executing the instant it's scheduled, leaving the previous round's image and
        // capsules briefly visible until `session.startNewGame()` itself flips `isLoading`.
        session.tiles = []
        session.isLoading = true
        newGameTask = Task {
            if session.isGauntletLadderMode && (session.isLadderRunFailed || session.isLadderRunComplete) {
                await session.startNewLadderRun()
            } else {
                await session.startNewGame()
            }
        }
    }

    private func switchToPhotosAndRetry() {
        session.setMediaSourceType(.local)
        startNewGame()
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
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore()))
        .environment(settings)
        .environment(achievements)
        .environment(SoundService())
}
