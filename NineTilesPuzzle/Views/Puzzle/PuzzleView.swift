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

    @State private var completion = PuzzleCompletionViewModel()
    @State private var showQuitAlert = false
    @State private var isSolving = false
    @State private var showTimeTrialDelta = false
    @State private var newGameTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Layer 1: centered main content — only Spacer/content/Spacer so centering
            // is never affected by supplementary elements in other layers
            VStack {
                if session.isLoading {
                    LoadingView()
                        // Removal is instant rather than fading, so this never lingers
                        // on screen crossfaded over the preview/grid that replaces it.
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                } else if session.isPreviewing, let image = session.previewImage {
                    ImagePreviewView(image: image, duration: session.currentPreviewDuration, isFogMode: session.isFogMode, onSkip: session.skipPreview)
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                } else if let error = session.error {
                    PuzzleErrorView(error: error, onRetry: startNewGame, onSwitchToPhotos: switchToPhotosAndRetry)
                        .transition(.opacity)
                } else {
                    Spacer()
                    PuzzleGridView(showReveal: completion.showCompletion)
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
                                .opacity(session.isZenMode ? completion.zenGlowOpacity : 0)
                        }
                        .overlay {
                            GeometryReader { proxy in
                                ForEach(completion.zenSparkles) { sparkle in
                                    ZenSparkleView(size: sparkle.size, color: sparkle.color, delay: sparkle.delay)
                                        .position(x: sparkle.x * proxy.size.width, y: sparkle.y * proxy.size.height)
                                }
                            }
                            .opacity(session.isZenMode ? completion.zenGlowOpacity : 0)
                            .allowsHitTesting(false)
                        }
                        .shadow(color: .teal.opacity(session.isZenMode ? completion.zenGlowOpacity * 0.7 : 0), radius: 28)
                        .scaleEffect(session.isZenMode ? completion.zenBreathScale : 1)
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
                        personalBestTime: session.personalBestTimeForCurrentSize,
                        timeTrialRemaining: session.timeTrialRemaining,
                        timeTrialScore: session.timeTrialScoreEstimate,
                        personalBestScore: session.personalBestScoreForCurrentSize,
                        isLadderMode: session.isLadderMode,
                        currentLadderStage: session.currentLadderStage,
                        ladderCumulativeScore: session.ladderCumulativeScore,
                        bestLadderScoreOverall: session.bestLadderScoreOverall,
                        movesRemaining: session.limitedMovesRemaining,
                        movesBudget: session.movesBudgetForCurrentSize
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    .opacity(streakVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: session.isLoading)
                    .animation(.easeInOut(duration: 0.35), value: session.isPreviewing)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completion.showCompletion)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completion.showTimeTrialFail)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completion.showLimitedMovesFail)

                    if session.isTimeTrialMode, let delta = session.lastTimeTrialDelta {
                        TimeTrialDeltaIndicatorView(delta: delta)
                            .padding(.top, 8)
                            .opacity(showTimeTrialDelta ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: showTimeTrialDelta)
                    }

                    Spacer()
                }
            }

            // Layer 3: completion overlay. Skipped in Zen mode — the solved picture reveal
            // (in PuzzleGridView) is the only feedback; the next puzzle starts on its own.
            if !session.isZenMode {
                VStack {
                    CompletionBannerView(gameMode: session.selectedGameMode, streak: session.currentStreakForCurrentSize, isNewRecord: completion.showNewRecord, moveCount: session.currentMoveCount, personalBest: session.personalBestForCurrentSize, elapsedTime: session.elapsedTime, personalBestTime: session.personalBestTimeForCurrentSize, isPracticeMode: settings.debugOverlayEnabled, timeTrialScore: session.timeTrialScore, personalBestScore: session.personalBestScoreForCurrentSize, isNewTimeTrialScoreRecord: completion.showNewTimeTrialScoreRecord, isLadderMode: session.isGauntletLadderMode, isLadderRunComplete: session.isLadderRunComplete, lastClearedLadderStage: session.lastClearedLadderStage, ladderCumulativeScore: session.ladderCumulativeScore, bestLadderScoreOverall: session.bestLadderScoreOverall, isNewLadderScoreRecord: completion.showNewLadderScoreRecord)
                        .padding(.top)
                        .padding(.horizontal)
                        .offset(x: completion.bannerOffset.width, y: (completion.showCompletion ? 0 : -300) + completion.bannerOffset.height)
                        .opacity(completion.showCompletion ? 1 : 0)
                        .gesture(
                            DragGesture()
                                .onChanged { value in completion.updateBannerDrag(value.translation) }
                                .onEnded { _ in completion.endBannerDrag() }
                        )

                    // Floats below the banner as its own layer — rather than growing the
                    // banner's card — and slides down out from behind it on appear.
                    if completion.showCompletion && completion.hasNewBestBadge(selectedGameMode: session.selectedGameMode) {
                        NewBestBadgesView(
                            showsStreak: session.selectedGameMode != .slide && session.selectedGameMode != .limitedMoves,
                            moveCount: session.currentMoveCount,
                            isNewMovesRecord: completion.showNewMovesRecord,
                            elapsedTime: session.elapsedTime,
                            isNewBestTime: completion.showNewBestTime,
                            isNewTimeTrialScoreRecord: completion.showNewTimeTrialScoreRecord,
                            timeTrialScore: session.timeTrialScore,
                            isNewLadderScoreRecord: completion.showNewLadderScoreRecord,
                            ladderCumulativeScore: session.ladderCumulativeScore,
                            isNewLadderStageRecord: completion.showNewLadderStageRecord,
                            ladderStageReached: session.lastClearedLadderStage
                        )
                        .padding(.horizontal)
                        .offset(completion.bannerOffset)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    Button(continueButtonLabel, action: startNewGame)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.bottom)
                        .offset(y: completion.showCompletion ? 0 : 300)
                        .opacity(completion.showCompletion ? 1 : 0)
                }
                .allowsHitTesting(completion.showCompletion)
            }

            // Layer 3b: Time Trial fail overlay — mutually exclusive with the completion
            // banner above, shown instead when the countdown reaches zero unsolved.
            if session.isTimeTrialMode {
                VStack {
                    TimeTrialFailView(
                        moveCount: session.currentMoveCount,
                        personalBestScore: session.personalBestScoreForCurrentSize,
                        isLadderMode: session.isGauntletLadderMode,
                        ladderStageReached: session.currentLadderStage,
                        ladderCumulativeScore: session.ladderCumulativeScore,
                        bestLadderStageReachedOverall: session.bestLadderStageReachedOverall
                    )
                        .padding(.top)
                        .padding(.horizontal)
                        .offset(y: completion.showTimeTrialFail ? 0 : -300)
                        .opacity(completion.showTimeTrialFail ? 1 : 0)

                    Spacer()

                    Button("Try Again", action: startNewGame)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.bottom)
                        .offset(y: completion.showTimeTrialFail ? 0 : 300)
                        .opacity(completion.showTimeTrialFail ? 1 : 0)
                }
                .allowsHitTesting(completion.showTimeTrialFail)
            }

            // Layer 3c: Limited Moves fail overlay — mirrors Layer 3b's Time Trial fail
            // overlay, mutually exclusive with the completion banner above.
            if session.isLimitedMovesMode {
                VStack {
                    LimitedMovesFailView(
                        moveCount: session.currentMoveCount,
                        personalBestMoves: session.personalBestForCurrentSize
                    )
                        .padding(.top)
                        .padding(.horizontal)
                        .offset(y: completion.showLimitedMovesFail ? 0 : -300)
                        .opacity(completion.showLimitedMovesFail ? 1 : 0)

                    Spacer()

                    Button("Try Again", action: startNewGame)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.bottom)
                        .offset(y: completion.showLimitedMovesFail ? 0 : 300)
                        .opacity(completion.showLimitedMovesFail ? 1 : 0)
                }
                .allowsHitTesting(completion.showLimitedMovesFail)
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
        .onChange(of: session.isNewRecord) { _, isRecord in
            completion.handleNewRecordChange(isRecord)
        }
        .onChange(of: session.isNewMovesRecord) { _, isRecord in
            completion.handleNewMovesRecordChange(isRecord)
        }
        .onChange(of: session.isNewBestTime) { _, isRecord in
            completion.handleNewBestTimeChange(isRecord)
        }
        .onChange(of: session.isNewTimeTrialScoreRecord) { _, isRecord in
            completion.handleNewTimeTrialScoreRecordChange(isRecord)
        }
        .onChange(of: session.isNewLadderScoreRecord) { _, isRecord in
            completion.handleNewLadderScoreRecordChange(isRecord)
        }
        .onChange(of: session.isNewLadderStageRecord) { _, isRecord in
            completion.handleNewLadderStageRecordChange(isRecord)
        }
        .onChange(of: session.isTimeTrialFailed) { _, failed in
            completion.handleTimeTrialFailedChange(failed)
        }
        .onChange(of: session.isLimitedMovesFailed) { _, failed in
            completion.handleLimitedMovesFailedChange(failed)
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
        (!session.tiles.isEmpty || session.isPreviewing) && !session.isSolved && !session.isTimeTrialFailed && !session.isLimitedMovesFailed
    }

    private var showSolveButton: Bool {
        let result = settings.debugOverlayEnabled
            && session.selectedGameMode == .slide
            && !session.tiles.isEmpty
            && !session.isSolved
        return result
    }

    private var streakVisible: Bool {
        !completion.showCompletion && !completion.showTimeTrialFail && !completion.showLimitedMovesFail
            && !session.isLoading && !session.isPreviewing && session.error == nil
    }

    /// "Continue" still applies to every non-ladder mode; a ladder run instead names what
    /// tapping it actually does next — advancing a stage, or starting a fresh run.
    private var continueButtonLabel: String {
        guard session.isGauntletLadderMode else { return "Continue" }
        return session.isLadderRunComplete ? "New Run" : "Next Stage"
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
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings))
        .environment(settings)
        .environment(achievements)
        .environment(SoundService())
}
