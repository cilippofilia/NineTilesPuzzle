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
    @Environment(DailyChallengeStore.self) private var dailyChallengeStore
    @Environment(WallOfFameStore.self) private var wallOfFameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var completion = PuzzleCompletionViewModel()
    @State private var showQuitAlert = false
    /// Set when the resume deep link pushed this view: the restored board is kept as-is
    /// instead of being wiped and reshuffled by the fresh-game lifecycle below.
    @State private var isResumedGame = false
    /// Drives the Quick Snap re-capture sheet shown when the player taps "Play Again" after
    /// solving a Quick Snap puzzle — every round starts on a freshly snapped frame.
    @State private var showQuickSnapRecapture = false
    @State private var isSolving = false
    @State private var showTimeTrialDelta = false
    @State private var newGameTask: Task<Void, Never>?
    /// The share image, rendered once when the puzzle is solved and cached here — rather than
    /// re-run through `ImageRenderer` on every toolbar/body re-evaluation while the completion
    /// banner is on screen.
    @State private var solvedPNG: SolvedPuzzleImage?

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
                PuzzleCompletionOverlayView(completion: completion, continueAction: handleContinue, dismissAction: leaveDailyChallenge)
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

        }
        // Layer 4: achievement unlock toast. Every achievement metric is only evaluated at
        // the instant a puzzle is solved (see `AchievementMetric.value`), so `isSolved` is
        // already true whenever `newlyUnlockedAchievement` is set — gating the toast on
        // `!session.isSolved` meant it could never actually render. `safeAreaInset` reserves
        // room for it at the bottom instead, which pushes the completion banner's
        // Continue/Back-to-Menu button up rather than sitting underneath the toast.
        .safeAreaInset(edge: .bottom) {
            if let achievement = achievementsStore.newlyUnlockedAchievement {
                AchievementToastView(achievement: achievement)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
            if session.consumePendingResume() {
                isResumedGame = true
            } else {
                session.tiles = []
                session.isLoading = true
            }
        }
        .task {
            if isResumedGame {
                // The resume deep link landed on a fully restored board — restart its
                // timers instead of wiping it for a fresh game.
                session.startTimersForRestoredGameIfNeeded()
            } else if session.isGauntletLadderMode {
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
            // Render the share card once, off the synchronous body pass. Cleared on the next
            // new game via `startNewGame()`.
            if solved {
                Task { solvedPNG = renderSolvedPNG() }
            } else {
                solvedPNG = nil
            }
        }
        // One handler mirrors every per-solve record flag in a single update; see `recordFlags`.
        .onChange(of: recordFlags) { _, flags in
            completion.applyRecords(flags)
            if flags.isNewMovesRecord {
                let slot: WallOfFameSlot = session.isDailyGameActive
                    ? .dailyBestMoves
                    : .bestMoves(gridSize: session.gridSize)
                captureWallOfFameCard(for: slot)
            }
            if flags.isNewBestTime {
                let slot: WallOfFameSlot = session.isDailyGameActive
                    ? .dailyBestTime
                    : .bestTime(gridSize: session.gridSize)
                captureWallOfFameCard(for: slot)
            }
            if flags.isNewLadderStageBestRecord {
                captureWallOfFameCard(for: .ladderStage(session.lastClearedLadderStage))
            }
        }
        .onChange(of: session.isNewCalendarStreakRecord) { _, isNew in
            guard isNew else { return }
            captureWallOfFameCard(for: .calendarStreak)
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
        .fullScreenCover(isPresented: $showQuickSnapRecapture) {
            QuickSnapCameraView(
                shotDuration: session.currentQuickSnapDuration,
                onCapture: { image in
                    showQuickSnapRecapture = false
                    session.refreshQuickSnapImage(with: image)
                    startNewGame()
                },
                // Backing out of the re-capture means the player is done — the puzzle they
                // just solved is already recorded, so leave Quick Snap and return to the menu.
                onCancel: {
                    showQuickSnapRecapture = false
                    leaveDailyChallenge()
                }
            )
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
                // Refresh after pausing so the Lock Screen reminder shows the board and elapsed
                // time exactly as the player left them — the moment the reminder becomes visible.
                session.refreshLiveActivity()
                // Same reasoning for the Resume widget: the home screen is about to show it.
                session.syncResumeWidget()
            } else if newPhase == .active, !session.isLoading, !session.isPreviewing {
                session.resumeTimers()
            }
        }
        .onDisappear {
            session.leaveGame()
        }
    }

    private func renderSolvedPNG() -> SolvedPuzzleImage? {
        guard let cgImage = session.croppedSourceImage else { return nil }
        let card = ShareCardView(
            image: cgImage,
            gridSize: session.gridSize,
            gameMode: session.selectedGameMode,
            moveCount: session.currentMoveCount,
            elapsedTime: session.elapsedTime,
            isDailyChallenge: session.isDailyGameActive,
            dailyDate: session.activeDailyDate,
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
            isNewLadderStageRecord: session.isNewLadderStageRecord,
            isNewLadderStageBestRecord: session.isNewLadderStageBestRecord
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

    /// "Continue"/"Play Again" from the completion banner. Quick Snap re-opens the camera so the
    /// next round plays a freshly snapped scene rather than reshuffling the shot just solved;
    /// every other mode simply starts a new game in place.
    private func handleContinue() {
        if session.isQuickSnapActive {
            showQuickSnapRecapture = true
        } else {
            startNewGame()
        }
    }

    private func startNewGame() {
        newGameTask?.cancel()

        solvedPNG = nil
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

    private func leaveDailyChallenge() {
        session.leaveGame()
        dismiss()
    }

    private func captureWallOfFameCard(for slot: WallOfFameSlot) {
        guard let cgImage = session.croppedSourceImage else { return }
        let ladderStage: Int? = if case .ladderStage(let stage) = slot { stage } else { nil }
        let card = ShareCardView(
            image: cgImage,
            gridSize: session.gridSize,
            gameMode: session.selectedGameMode,
            moveCount: session.currentMoveCount,
            elapsedTime: session.elapsedTime,
            isDailyChallenge: session.isDailyGameActive,
            dailyDate: session.activeDailyDate,
            calendarStreak: session.dailyCalendarStreak,
            ladderStage: ladderStage,
            ladderStageScore: ladderStage != nil ? session.lastLadderStageScore : nil
        )
        // Rendering is deferred to a Task so the `.onChange(of: recordFlags)` handler that
        // triggers this returns immediately instead of blocking on an ImageRenderer pass.
        Task {
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0
            guard let captured = renderer.cgImage else { return }
            wallOfFameStore.save(captured, for: slot)
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
