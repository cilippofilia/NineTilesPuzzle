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
    @Environment(DailyReminderService.self) private var dailyReminderService
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
    @State private var showChallengeSendSheet = false
    /// Set by "Challenge Them Back" before starting the fresh game its reply needs — a
    /// rechallenge can't reuse the just-played challenge's embedded image/seed (requirement:
    /// "new image/seed, same mode+grid"), so this survives across that new game and
    /// auto-opens the send sheet once it solves.
    @State private var pendingRechallenge: (opponentName: String, parentChallengeID: UUID)?
    @State private var showChallengeResultSendSheet = false
    /// Drives `TimeTrialResumeOverlay` — set true while the "Get Ready" grace period is
    /// counting down after a Time Trial / Gauntlet Ladder puzzle returns from the background.
    @State private var isShowingResumeCountdown = false
    @State private var resumeCountdownValue = 3
    @State private var resumeCountdownTask: Task<Void, Never>?

    var body: some View {
        // Split into two independently type-checked expressions to avoid the compiler's
        // expression complexity limit on long modifier chains.
        let gameView = ZStack {
            // Layer 1: centered main content — only Spacer/content/Spacer so centering
            // is never affected by supplementary elements in other layers. Crucially, this
            // sits outside the `safeAreaInset`s below: those resize the safe area of whatever
            // they're attached to, and attaching them here would reflow this layer's Spacers
            // (and visibly shift the solved grid) every time the achievement toast or the
            // power-up toolbar appears or disappears.
            PuzzleMainContentLayer(
                completion: completion,
                startNewGame: startNewGame,
                switchToPhotosAndRetry: switchToPhotosAndRetry
            )

            ZStack {
                // Layers 2 & 3: floating status bar and completion banner. Both are hidden in
                // Zen mode, which shows nothing but the puzzle itself.
                if !session.isZenMode {
                    PuzzleStatusOverlayLayer(completion: completion, showTimeTrialDelta: showTimeTrialDelta)
                    PuzzleCompletionOverlayView(
                        completion: completion,
                        continueAction: handleContinue,
                        dismissAction: leaveDailyChallenge,
                        rechallengeAction: rechallengeActionIfChallengeActive,
                        sendResultAction: sendResultActionIfChallengeActive
                    )
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

                // Layer 3d: Peek power-up — re-shows the full image mid-game, reusing the same
                // view the pre-shuffle "memorize the image" step uses.
                if session.isPeeking, let previewImage = session.previewImage {
                    ImagePreviewView(
                        image: previewImage,
                        duration: settings.peekDuration,
                        isFogMode: false,
                        isDailyChallenge: session.isDailyGameActive,
                        gameMode: session.selectedGameMode,
                        onSkip: session.skipPeek
                    )
                    .transition(.opacity)
                }

                // Layer 3e: Time Trial / Gauntlet Ladder resume grace — shown while the app is
                // back in the foreground but the countdown is deliberately still frozen.
                if session.isTimeTrialMode {
                    TimeTrialResumeOverlay(isShowing: isShowingResumeCountdown, value: resumeCountdownValue)
                }
            }
            // Layer 4: achievement unlock toast. Every achievement metric is only evaluated at
            // the instant a puzzle is solved (see `AchievementMetric.value`), so `isSolved` is
            // already true whenever `newlyUnlockedAchievement` is set — gating the toast on
            // `!session.isSolved` meant it could never actually render. `safeAreaInset` reserves
            // room for it at the bottom instead, which pushes the completion banner's
            // Continue/Back-to-Menu button up rather than sitting underneath the toast — scoped
            // to this inner ZStack (not `gameView`) so that reserved space never touches
            // Layer 1's centering.
            .safeAreaInset(edge: .bottom) {
                if let achievement = achievementsStore.newlyUnlockedAchievement {
                    AchievementToastView(achievement: achievement)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Layer 5: power-up inventory bar, shown below the grid whenever a game is actually
            // in progress. Hidden in Zen mode along with the rest of the HUD — Zen is meant to be
            // nothing but the puzzle. Same scoping rationale as Layer 4 above.
            .safeAreaInset(edge: .bottom) {
                if settings.powerUpsEnabled && !session.isZenMode && isGameActive {
                    PuzzlePowerUpToolbarView()
                        .padding(.bottom, 8)
                }
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
                if pendingRechallenge != nil { showChallengeSendSheet = true }
            } else {
                solvedPNG = nil
            }
            if solved && session.isDailyGameActive {
                handleDailyChallengeSolved()
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
        // Third independently type-checked expression — the toolbar/sheet modifiers below
        // pushed the previous single chain over the compiler's expression complexity limit.
        let toolbarView = gameView
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

            if completion.showCompletion, isChallengeEligible {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Challenge a Friend", systemImage: "person.2.fill") {
                        showChallengeSendSheet = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .fullScreenCover(isPresented: $showQuickSnapRecapture) {
            QuickSnapCameraView(
                shotDuration: session.currentQuickSnapDuration,
                onCapture: { image in
                    showQuickSnapRecapture = false
                    session.refreshQuickSnapImage(with: image)
                    // Bumped here rather than when "Continue" first opened the camera sheet, so
                    // it can't race Billboard's `.fullScreenCover` against this one still being
                    // presented — by the time this fires, the camera sheet is already closing.
                    session.completedGameSignal += 1
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
        return toolbarView
        .sheet(isPresented: $showChallengeSendSheet, onDismiss: { pendingRechallenge = nil }) {
            if let cgImage = session.croppedSourceImage {
                ChallengeSendSheet(
                    gameMode: session.selectedGameMode,
                    gridSize: session.gridSize,
                    image: cgImage,
                    moves: session.currentMoveCount,
                    time: session.elapsedTime,
                    opponentLabel: pendingRechallenge?.opponentName,
                    parentChallengeID: pendingRechallenge?.parentChallengeID
                )
            }
        }
        .sheet(isPresented: $showChallengeResultSendSheet) {
            if let challenge = session.activeChallenge {
                ChallengeResultSendSheet(
                    challengeID: challenge.id,
                    opponentName: challenge.senderName,
                    moves: session.currentMoveCount,
                    time: session.elapsedTime
                )
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
            switch newPhase {
            case .background:
                // `.inactive` already froze the timers and cancelled any resume countdown on
                // the way here (every backgrounding passes through `.inactive` first), but
                // `pauseTimers()` is idempotent so this stays correct even if that ever changes.
                resumeCountdownTask?.cancel()
                isShowingResumeCountdown = false
                session.pauseTimers()
                // Refresh after pausing so the Lock Screen reminder shows the board and elapsed
                // time exactly as the player left them — the moment the reminder becomes visible.
                session.refreshLiveActivity()
            case .inactive:
                // Covers real interruptions that never reach `.background` — a phone call,
                // Face ID prompt, Control Center, or the app switcher preview — which
                // previously left the countdown ticking while the player couldn't interact.
                resumeCountdownTask?.cancel()
                isShowingResumeCountdown = false
                session.pauseTimers()
            case .active:
                guard !session.isLoading, !session.isPreviewing else { break }
                if session.isTimeTrialMode, !session.isSolved, !session.isTimeTrialFailed,
                   session.timeTrialRemaining > 0 {
                    beginResumeCountdown()
                } else {
                    session.resumeTimers()
                }
            default:
                break
            }
        }
        .onDisappear {
            resumeCountdownTask?.cancel()
            if session.isSolved { session.completedGameSignal += 1 }
            session.leaveGame()
        }
    }

    /// Delays `GameSession.resumeTimers()` behind a 3-2-1 "Get Ready" grace period so the Time
    /// Trial / Gauntlet Ladder countdown doesn't start ticking the instant the screen becomes
    /// visible again, before the player has had a moment to reorient.
    private func beginResumeCountdown() {
        resumeCountdownValue = 3
        isShowingResumeCountdown = true
        resumeCountdownTask?.cancel()
        resumeCountdownTask = Task {
            var value = 3
            while value > 1 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                value -= 1
                resumeCountdownValue = value
            }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            isShowingResumeCountdown = false
            session.resumeTimers()
        }
    }

    /// Keeps the daily reminder notification in sync with today's completion, and — the
    /// very first time ever — prompts for notification permission at a moment the player
    /// is already engaged, rather than on cold launch where it's easy to reflexively deny.
    private func handleDailyChallengeSolved() {
        if session.isFirstDailyCompletion {
            Task {
                let granted = await dailyReminderService.requestAuthorization()
                if granted { settings.setDailyReminderEnabled(true) }
                dailyReminderService.rescheduleIfNeeded(
                    enabled: settings.dailyReminderEnabled,
                    time: settings.dailyReminderTime,
                    completedToday: true
                )
            }
        } else {
            dailyReminderService.rescheduleIfNeeded(
                enabled: settings.dailyReminderEnabled,
                time: settings.dailyReminderTime,
                completedToday: true
            )
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

    private var rechallengeActionIfChallengeActive: (() -> Void)? {
        guard session.isChallengeGameActive else { return nil }
        return challengeThemBack
    }

    /// `nil` when there's no active challenge to reply to, or when the reply already went out
    /// automatically over a still-open Nearby connection (`GameSession.challengeArrivedLive`) —
    /// no need to offer a manual resend in that case.
    private var sendResultActionIfChallengeActive: (() -> Void)? {
        guard session.isChallengeGameActive, !session.challengeArrivedLive else { return nil }
        return { showChallengeResultSendSheet = true }
    }

    /// Whether the just-finished game can be packaged into a Challenge Friends puzzle —
    /// Zen has no natural win/lose metric, and a Gauntlet Ladder run isn't a single
    /// reproducible puzzle instance.
    private var isChallengeEligible: Bool {
        settings.challengeFriendsEnabled
            && ChallengeStore.eligibleGameModes.contains(session.selectedGameMode)
            && !session.isGauntletLadderMode
            && session.croppedSourceImage != nil
    }

    /// "Challenge Them Back": a rechallenge needs a fresh image/seed, not the one just played,
    /// so this starts a brand-new ordinary game in the same mode/grid size and defers opening
    /// the send sheet until that new game solves (see the `onChange(of: session.isSolved)`
    /// handler above and `pendingRechallenge`).
    private func challengeThemBack() {
        guard let challenge = session.activeChallenge else { return }
        let mode = challenge.gameMode
        let size = challenge.gridSize
        pendingRechallenge = (challenge.senderName, challenge.id)
        session.leaveGame()
        session.setGameMode(mode)
        session.setGridSize(size)
        startNewGame()
    }

    private var showSolveButton: Bool {
        settings.debugOverlayEnabled
            && session.selectedGameMode == .slide
            && !session.tiles.isEmpty
            && !session.isSolved
    }

    /// "Continue"/"Play Again" from the completion banner. Quick Snap re-opens the camera so the
    /// next round plays a freshly snapped scene rather than reshuffling the shot just solved;
    /// every other mode simply starts a new game in place. Quick Snap's `completedGameSignal`
    /// bump happens later, in the recapture sheet's `onCapture` — not here — so it can't race
    /// Billboard's own `.fullScreenCover` against the camera sheet still being on screen.
    private func handleContinue() {
        if session.isQuickSnapActive {
            showQuickSnapRecapture = true
        } else {
            session.completedGameSignal += 1
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

        let gridSize = session.gridSize
        var board = [Int](repeating: 0, count: gridSize * gridSize)
        for tile in session.tiles { board[tile.currentIndex] = tile.id }

        Task {
            let moves = await Task.detached {
                SlideSolver.solveBoard(board, gridSize: gridSize)
            }.value

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
    let powerUps = PowerUpStore()
    PuzzleView()
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore(), powerUpStore: powerUps, challengeStore: ChallengeStore()))
        .environment(settings)
        .environment(achievements)
        .environment(powerUps)
        .environment(SoundService())
        .environment(DailyReminderService())
}
