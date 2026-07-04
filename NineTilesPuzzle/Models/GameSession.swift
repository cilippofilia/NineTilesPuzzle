//
//  GameSession.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

/// The game currently configured and/or in progress: which mode/size/media to play, the
/// live board, and the timers that run while playing. Reports completed moves and games to
/// `StatsStore` and `AchievementsStore`, and reads `SettingsStore` for preferences that
/// affect play (preview length, streak countdown length, debug/practice mode).
@MainActor
@Observable
final class GameSession {
    private let statsStore: StatsStore
    private let achievementsStore: AchievementsStore
    private let settingsStore: SettingsStore
    private let dailyChallengeStore: DailyChallengeStore
    private let defaults: PersistenceStore

    private let swapEngine = SwapEngine()
    private let slideEngine = SlideEngine()
    private var previewSleepTask: Task<Void, Never>?

    /// Reused across every save/restore so we don't pay a fresh coder allocation on each
    /// move. Both are stateless for our value types, so sharing them is safe on the actor.
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    var gridSize: Int = 3
    var useRandomSize: Bool = false
    var mediaSourceType: MediaSourceType = .numbers
    var tiles: [TileModel] = []
    var tileImages: [Int: CGImage] = [:]
    var sourceImage: CGImage?
    /// The center-cropped square `sourceImage` is sliced from — what tiles actually show,
    /// used to reveal the complete picture on solve without a mismatched, uncropped edge.
    /// In Chaos Mode this is the post-transform image (matching the tiles), not the original.
    var croppedSourceImage: CGImage?
    /// The pre-shuffle "memorize the image" preview, shown by `ImagePreviewView`. Always the
    /// untouched, untransformed crop — in Chaos Mode the player should study the real photo,
    /// not the mirrored/inverted/pixelated version the tiles are about to show, otherwise the
    /// "memorize" step would just be teaching them the wrong picture.
    var previewImage: CGImage?
    var isLoading = false
    var isPreviewing = false
    var isSolved = false
    var isNewRecord: Bool = false
    var currentMoveCount: Int = 0
    var isNewMovesRecord: Bool = false
    var elapsedTime: TimeInterval = 0
    var isNewBestTime: Bool = false
    var error: Error?
    var selectedGameMode: GameMode = .slide
    var isNewTimeTrialScoreRecord: Bool = false
    var timeTrialScore: Int = 0
    var isNewCalendarStreakRecord: Bool = false

    /// True while the player is in a Daily Challenge game. Transient — not persisted,
    /// so a force-quit always starts fresh on the next launch rather than accidentally
    /// routing a regular game through the daily image/shuffle path.
    private(set) var isDailyGameActive: Bool = false
    /// The user's `selectedGameMode` before entering a daily game, restored in `leaveGame()`.
    private var preDailyGameMode: GameMode? = nil

    /// True while the player is in a Quick Snap game — a plain Swap puzzle whose image was
    /// just captured by the camera. Transient like `isDailyGameActive`, so a force-quit
    /// resumes the puzzle as an ordinary Swap game rather than re-routing through capture.
    private(set) var isQuickSnapActive: Bool = false
    /// The user's `selectedGameMode` before entering Quick Snap, restored in `leaveGame()`.
    private var preQuickSnapGameMode: GameMode? = nil
    /// The frame captured for the current Quick Snap game, consumed by `startNewGame()` in
    /// place of a network/photo-library fetch. Kept until `leaveGame()` so "Continue" reshuffles
    /// the same shot rather than falling through to a source that doesn't exist for this mode.
    private var quickSnapImage: CGImage?

    /// The "Single Puzzle vs Ladder" toggle for Time Trial — a sticky preference, like
    /// `mediaSourceType` generally is, rather than something that resets when the player
    /// switches away from Time Trial and back.
    var isLadderMode: Bool = false
    private(set) var currentLadderStage: Int = 1
    /// Snapshot of `currentLadderStage` taken right before it advances, so completion UI can
    /// say "Stage N Cleared!" for the stage just cleared rather than the upcoming one.
    private(set) var lastClearedLadderStage: Int = 0
    private(set) var ladderCumulativeScore: Int = 0
    private(set) var ladderWinStreak: Int = 0
    private(set) var isLadderRunComplete = false
    private(set) var isLadderRunFailed = false
    var isNewLadderScoreRecord: Bool = false
    var isNewLadderStageRecord: Bool = false

    private(set) var timerRemaining: Double = 30
    private(set) var isTimerRunning = false
    private(set) var didBreakStreak = false

    /// True once any move this game failed to lock a new tile correctly — tracked only for
    /// the swap-style engine (Slide never locks tiles, so "every move locks a tile" isn't a
    /// meaningful question there). Backs the "Perfectionist" achievement.
    private(set) var hasHadWastedMoveThisGame = false

    private(set) var timeTrialRemaining: Double = 0
    private(set) var isTimeTrialRunning = false
    private(set) var isTimeTrialFailed = false
    private(set) var isLimitedMovesFailed = false
    /// The bonus (positive) or penalty (negative) seconds applied by the most recent move,
    /// for the HUD's transient "+1s"/"-2s" indicator. `nil` before any move has been made.
    private(set) var lastTimeTrialDelta: TimeInterval?

    private var countdownTask: Task<Void, Never>?
    private var stopwatchTask: Task<Void, Never>?
    private var timeTrialTask: Task<Void, Never>?
    private var timeTrialEndDate: Date?

    /// Zen mode tracks nothing but the number of games played: no streaks, no personal
    /// bests, no achievements — just an uninterrupted, judgment-free puzzle loop.
    var isZenMode: Bool { selectedGameMode == .zen }
    var isTimeTrialMode: Bool { selectedGameMode == .timeTrial }
    var isGauntletLadderMode: Bool { isTimeTrialMode && isLadderMode }
    var isLimitedMovesMode: Bool { selectedGameMode == .limitedMoves }
    var isFogMode: Bool { selectedGameMode == .fog }
    var currentPreviewDuration: Double { settingsStore.previewDuration }
    /// Seconds on the Quick Snap capture countdown, chosen by the player in Settings.
    var currentQuickSnapDuration: Double { settingsStore.quickSnapDuration }

    // MARK: - Daily Challenge

    var dailyCalendarStreak: Int { dailyChallengeStore.calendarStreak }
    var dailyBestCalendarStreak: Int { dailyChallengeStore.bestCalendarStreak }
    var isDailyCompletedToday: Bool { dailyChallengeStore.isDailyCompletedToday }
    var dailyBestMoves: Int? { dailyChallengeStore.bestMoves }
    var dailyBestTime: TimeInterval? { dailyChallengeStore.bestTime }
    var dailyEffectiveDate: Date { dailyChallengeStore.effectiveDate }

    /// Marks this session as a Daily Challenge game. Must be called before navigating
    /// to `PuzzleView` — `startNewGame()` checks `isDailyGameActive` to use the
    /// seeded image/shuffle path instead of the regular source/engine path.
    /// Saves the user's current game mode and replaces it with today's seeded mode;
    /// `leaveGame()` restores the original.
    func enterDailyMode() {
        preDailyGameMode = selectedGameMode
        selectedGameMode = DailyChallengeSeeder.gameMode(for: dailyChallengeStore.effectiveDate)
        isDailyGameActive = true
    }

    /// Marks this session as a Quick Snap game using the just-captured camera `image`. Must be
    /// called before navigating to `PuzzleView` — `startNewGame()` checks `isQuickSnapActive`
    /// to slice this frame directly instead of fetching from a headless image source. Forces
    /// Swap play (the mode Quick Snap runs on) and saves the user's mode for `leaveGame()` to
    /// restore, mirroring `enterDailyMode()`.
    func enterQuickSnapMode(with image: CGImage) {
        preQuickSnapGameMode = selectedGameMode
        selectedGameMode = .swap
        quickSnapImage = image
        isQuickSnapActive = true
    }

    /// Replaces the captured frame for an already-active Quick Snap game with a freshly snapped
    /// `image`, so "Play Again" starts on a brand-new shot rather than reshuffling the old one.
    /// Unlike `enterQuickSnapMode(with:)` this leaves the saved pre-Quick-Snap mode untouched —
    /// the player is still inside the same Quick Snap session, so `leaveGame()` must restore the
    /// mode they had before the *first* capture, not `.swap`.
    func refreshQuickSnapImage(with image: CGImage) {
        quickSnapImage = image
    }

    /// Total moves allowed this game; Limited Moves' flat budget per grid size.
    var movesBudgetForCurrentSize: Int { LimitedMovesRules.moveBudget(forGridSize: gridSize) }
    /// Moves left before `isLimitedMovesFailed` trips — every move costs 1, regardless of
    /// whether it locks a tile correctly.
    var limitedMovesRemaining: Int { max(0, movesBudgetForCurrentSize - currentMoveCount) }

    var currentStatsKey: StatsKey { StatsKey(gridSize: gridSize, gameMode: selectedGameMode) }

    private var activeEngine: any GameEngine {
        switch selectedGameMode {
        case .slide:
            return slideEngine
        default:
            return swapEngine
        }
    }

    init(
        statsStore: StatsStore,
        achievementsStore: AchievementsStore,
        settingsStore: SettingsStore,
        dailyChallengeStore: DailyChallengeStore,
        defaults: PersistenceStore = UserDefaults.standard
    ) {
        self.statsStore = statsStore
        self.achievementsStore = achievementsStore
        self.settingsStore = settingsStore
        self.dailyChallengeStore = dailyChallengeStore
        self.defaults = defaults
        restoreFromUserDefaults()
        achievementsStore.checkAchievements(using: statsStore)
        Task {
            await achievementsStore.refreshAchievementsFromRemote()
            achievementsStore.checkAchievements(using: statsStore)
        }
    }

    func startCountdown() {
        guard settingsStore.streakCountdownDuration > 0 else { return }
        stopCountdown()
        timerRemaining = settingsStore.streakCountdownDuration
        isTimerRunning = true
        let end = Date.now.addingTimeInterval(settingsStore.streakCountdownDuration)
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 {
                    statsStore.resetStreak(for: currentStatsKey)
                    isNewRecord = false
                    didBreakStreak.toggle()
                    stopCountdown()
                    return
                }
                timerRemaining = remaining
            }
        }
    }

    func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        timerRemaining = settingsStore.streakCountdownDuration
        isTimerRunning = false
    }

    /// Starts a fresh Time Trial countdown at the base time limit for the current grid
    /// size. Unlike `startCountdown()`, the end date is mutable instance state rather than
    /// a value captured by the task — `applyTimeTrialMoveOutcome` nudges it on every move so
    /// the running task picks up combo bonuses/misplay penalties on its very next tick.
    func startTimeTrialCountdown() {
        stopTimeTrialCountdown()
        isTimeTrialFailed = false
        lastTimeTrialDelta = nil
        let limit = isGauntletLadderMode
            ? GauntletLadderRules.stage(currentLadderStage).baseTimeLimit
            : TimeTrialRules.baseTimeLimit(forGridSize: gridSize)
        timeTrialRemaining = limit
        isTimeTrialRunning = true
        timeTrialEndDate = Date.now.addingTimeInterval(limit)
        timeTrialTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let end = timeTrialEndDate else { break }
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 {
                    timeTrialRemaining = 0
                    isTimeTrialFailed = true
                    if isGauntletLadderMode { isLadderRunFailed = true }
                    stopTimeTrialCountdown()
                    saveToUserDefaults()
                    return
                }
                timeTrialRemaining = remaining
            }
        }
    }

    /// Cancels the running Time Trial countdown task. Deliberately doesn't reset
    /// `timeTrialRemaining`/`isTimeTrialFailed` — callers that solve or fail the puzzle need
    /// those values to still reflect the final state for scoring and the result overlay.
    func stopTimeTrialCountdown() {
        timeTrialTask?.cancel()
        timeTrialTask = nil
        isTimeTrialRunning = false
    }

    /// Starts (or resumes) the elapsed-time stopwatch, anchored so a resumed game continues
    /// from its persisted `elapsedTime` rather than restarting at zero.
    func startStopwatch() {
        stopwatchTask?.cancel()
        let start = Date.now.addingTimeInterval(-elapsedTime)
        stopwatchTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                elapsedTime = Date.now.timeIntervalSince(start)
            }
        }
    }

    func stopStopwatch() {
        stopwatchTask?.cancel()
        stopwatchTask = nil
    }

    /// Suspends all active timers without resetting their remaining values, so
    /// `resumeTimers()` can restart each one exactly where it left off.
    func pauseTimers() {
        countdownTask?.cancel()
        countdownTask = nil
        isTimerRunning = false
        stopTimeTrialCountdown()    // preserves timeTrialRemaining by design
        stopStopwatch()             // preserves elapsedTime by design
    }

    /// Restarts whichever timers should be running given the current game state.
    /// Safe to call speculatively — each guard checks whether the timer was actually active.
    func resumeTimers() {
        guard !isSolved, !isTimeTrialFailed, !isLimitedMovesFailed else { return }
        if currentStreakForCurrentSize > 0 && timerRemaining > 0 {
            resumeCountdown()
        }
        if isTimeTrialMode && timeTrialRemaining > 0 {
            resumeTimeTrialCountdown()
        }
        if currentMoveCount > 0 {
            startStopwatch()
        }
    }

    /// Restarts the streak countdown from the current `timerRemaining` value.
    private func resumeCountdown() {
        guard settingsStore.streakCountdownDuration > 0 else { return }
        isTimerRunning = true
        let end = Date.now.addingTimeInterval(timerRemaining)
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 {
                    statsStore.resetStreak(for: currentStatsKey)
                    isNewRecord = false
                    didBreakStreak.toggle()
                    stopCountdown()
                    return
                }
                timerRemaining = remaining
            }
        }
    }

    /// Restarts the Time Trial countdown from the current `timeTrialRemaining` value.
    private func resumeTimeTrialCountdown() {
        isTimeTrialRunning = true
        timeTrialEndDate = Date.now.addingTimeInterval(timeTrialRemaining)
        timeTrialTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let end = timeTrialEndDate else { break }
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 {
                    timeTrialRemaining = 0
                    isTimeTrialFailed = true
                    if isGauntletLadderMode { isLadderRunFailed = true }
                    stopTimeTrialCountdown()
                    saveToUserDefaults()
                    return
                }
                timeTrialRemaining = remaining
            }
        }
    }

    /// Fetches a fresh image, slices it, shuffles the tiles, and persists state. In `.numbers`
    /// media mode there is no image to fetch or preview — tiles are shuffled immediately.
    func startNewGame() async {
        // Grid size is determined by mode priority: daily (fixed 4×4) > ladder (stage
        // table) > random > user-selected. Each overrides the one below it.
        if isDailyGameActive {
            gridSize = DailyChallengeSeeder.gridSize(for: dailyChallengeStore.effectiveDate)
        } else if isGauntletLadderMode {
            gridSize = GauntletLadderRules.stage(currentLadderStage).gridSize
        } else if useRandomSize {
            gridSize = Int.random(in: 3...8)
        }
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        previewImage = nil
        isLoading = true
        isSolved = false
        isNewRecord = false
        currentMoveCount = 0
        isNewMovesRecord = false
        elapsedTime = 0
        isNewBestTime = false
        isNewTimeTrialScoreRecord = false
        isNewCalendarStreakRecord = false
        timeTrialScore = 0
        isLadderRunComplete = false
        isNewLadderScoreRecord = false
        isNewLadderStageRecord = false
        isLimitedMovesFailed = false
        hasHadWastedMoveThisGame = false
        // Otherwise this stays stuck from a previous Time Trial run that ended in failure —
        // `startTimeTrialCountdown()` only resets it when re-entering Time Trial itself, so
        // every other mode's `swapTiles` (which guards on this flag regardless of mode)
        // would silently block every move forever afterward.
        isTimeTrialFailed = false
        error = nil
        stopTimeTrialCountdown()
        stopStopwatch()
        stopCountdown()

        let initial = (0..<gridSize * gridSize).map {
            TileModel(id: $0, currentIndex: $0, isLocked: false)
        }

        // Daily and Quick Snap always play with a real image (seeded remote / camera frame)
        // regardless of the user's media preference, so bypass the numbers-only fast path.
        guard mediaSourceType != .numbers || isDailyGameActive || isQuickSnapActive else {
            isLoading = false
            tiles = activeEngine.shuffle(initial, gridSize: gridSize)
            if currentStreakForCurrentSize > 0 { startCountdown() }
            if isTimeTrialMode { startTimeTrialCountdown() }
            saveToUserDefaults()
            return
        }

        do {
            let image: CGImage
            if isQuickSnapActive {
                // The frame was already captured through the camera sheet; there is no
                // headless source to fetch from, so use it directly.
                guard let captured = quickSnapImage else {
                    throw ImageSourceError.providerUnavailable
                }
                image = captured
            } else if isDailyGameActive {
                do {
                    image = try await DailyImageSource(date: dailyChallengeStore.effectiveDate).fetchImage()
                } catch {
                    throw ImageSourceError.providerUnavailable
                }
            } else {
                switch mediaSourceType {
                case .local:
                    image = try await ImageService(primarySource: PhotoLibraryImageSource()).loadImage().image
                case .mixed:
                    // Mixed already accepts photo-library images as a valid outcome, so a failed
                    // remote fetch falls back to a real library photo rather than the bundled
                    // placeholder — unlike `.random`, where the player explicitly chose Internet.
                    image = if Bool.random() {
                        try await ImageService(
                            primarySource: RemoteImageSource(),
                            fallbackSource: PhotoLibraryImageSource()
                        ).loadImage().image
                    } else {
                        try await ImageService(primarySource: PhotoLibraryImageSource()).loadImage().image
                    }
                default: // .random; .numbers is handled above
                    // No bundled-image fallback here: a player who chose Internet-only shouldn't
                    // keep silently playing the same static placeholder every game when the
                    // provider is down — surface it so they can switch media source instead.
                    do {
                        image = try await RemoteImageSource().fetchImage()
                    } catch {
                        throw ImageSourceError.providerUnavailable
                    }
                }
            }
            let slicer = ImageSlicer()
            let cropped = slicer.centerCrop(image)
            // The preview always shows this untouched crop — Chaos Mode's transform is baked
            // in below, after the preview's source is captured, so "memorize the image" still
            // teaches the real photo even though the tiles are about to show something else.
            previewImage = cropped
            var workingImage = cropped
            // Baked into the image itself, before slicing, rather than kept as separate
            // transform state — `sourceImage` (below) is what gets persisted and re-sliced
            // on restore, so a transformed image survives backgrounding for free with no
            // extra persistence key, and never re-rolls to a different transform than the
            // one the player's tiles were actually shuffled against.
            if selectedGameMode == .chaos {
                workingImage = ChaosTransform.random().apply(to: workingImage)
            }
            sourceImage = workingImage
            croppedSourceImage = workingImage
            let slices = slicer.slice(workingImage, into: gridSize * gridSize)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })

            isLoading = false

            // Quick Snap skips the "memorize the image" phase entirely — the player just
            // watched the scene through the capture countdown, so a second memorize step
            // would be redundant; shuffle starts immediately.
            let previewDuration = settingsStore.previewDuration
            if previewDuration > 0 && !isQuickSnapActive {
                isPreviewing = true
                previewSleepTask = Task { try? await Task.sleep(for: .seconds(previewDuration)) }
                await previewSleepTask?.value
                previewSleepTask = nil
                isPreviewing = false
            }

            if isDailyGameActive {
                // Apply a deterministic shuffle seeded from today's date so every player
                // gets the same starting arrangement. Slide mode requires a solvability
                // check; swap/limited-moves use a simpler derangement.
                let seed = DailyChallengeSeeder.seed(for: dailyChallengeStore.effectiveDate)
                if selectedGameMode == .slide {
                    let board = DailyChallengeSeeder.shuffledSlideBoard(count: initial.count, gridSize: gridSize, seed: seed)
                    for position in initial.indices {
                        initial[board[position]].currentIndex = position
                        initial[board[position]].isLocked = false
                    }
                } else {
                    let positions = DailyChallengeSeeder.shuffledPositions(count: initial.count, seed: seed)
                    for i in initial.indices {
                        initial[i].currentIndex = positions[i]
                        initial[i].isLocked = false
                    }
                }
                tiles = initial
            } else {
                tiles = activeEngine.shuffle(initial, gridSize: gridSize)
                if currentStreakForCurrentSize > 0 { startCountdown() }
                if isTimeTrialMode { startTimeTrialCountdown() }
            }
            saveToUserDefaults()
        } catch {
            self.error = error
            isLoading = false
        }
    }

    /// Resets ladder progress to Stage 1 and starts it. Distinct from `startNewGame()`,
    /// which resets only the current puzzle/stage — `startNewGame()` is also what advances
    /// from stage N to stage N+1 via the existing "Continue" button, so it must never zero
    /// the run's cumulative score or streak.
    func startNewLadderRun() async {
        currentLadderStage = 1
        lastClearedLadderStage = 0
        ladderCumulativeScore = 0
        ladderWinStreak = 0
        isLadderRunFailed = false
        isLadderRunComplete = false
        gridSize = GauntletLadderRules.stage(1).gridSize
        await startNewGame()
    }

    /// Attempts to swap the tiles at `sourceIndex` and `targetIndex`; no-ops if either is locked or indices are equal.
    func swapTiles(from sourceIndex: Int, to targetIndex: Int) {
        guard !isTimeTrialFailed, !isLimitedMovesFailed else { return }
        guard sourceIndex != targetIndex else { return }
        guard
            let source = tiles.first(where: { $0.currentIndex == sourceIndex }),
            let target = tiles.first(where: { $0.currentIndex == targetIndex }),
            !source.isLocked,
            !target.isLocked
        else { return }

        let correctBefore = tiles.filter { $0.isCorrect }.count
        swapEngine.swap(&tiles, from: sourceIndex, to: targetIndex)
        if isFogMode {
            withAnimation(.easeInOut(duration: 0.45)) {
                source.hasBeenMoved = true
                target.hasBeenMoved = true
            }
        }
        registerMove(correctBefore: correctBefore)
    }

    /// Attempts to slide the tile at `sourceIndex` into the empty cell; no-ops unless they're adjacent.
    /// Returns whether a move occurred.
    @discardableResult
    func slideTile(from sourceIndex: Int) -> Bool {
        guard
            let blankIndex = slideEngine.blankIndex(in: tiles),
            blankIndex != sourceIndex,
            slideEngine.areAdjacent(sourceIndex, blankIndex, gridSize: gridSize)
        else { return false }

        let correctBefore = tiles.filter { $0.isCorrect }.count
        slideEngine.slide(&tiles, from: sourceIndex, gridSize: gridSize)
        registerMove(correctBefore: correctBefore)
        return true
    }

    /// Shared bookkeeping after a move: move count, solved/streak/records, achievements, and persistence.
    private func registerMove(correctBefore: Int) {
        // The stopwatch starts on the first move, not at game start, so memorizing the
        // preview image or just thinking before moving doesn't count against solve time.
        if currentMoveCount == 0 { startStopwatch() }
        currentMoveCount += 1
        isSolved = activeEngine.isSolved(tiles)

        let key = currentStatsKey
        let debugOverlayEnabled = settingsStore.debugOverlayEnabled
        let newlyCorrect = tiles.filter { $0.isCorrect }.count - correctBefore

        // Slide never locks tiles, so a tile sliding in and back out again isn't a
        // "wasted move" in the same sense as a swap-style engine's permanent lock.
        if selectedGameMode != .slide && newlyCorrect <= 0 {
            hasHadWastedMoveThisGame = true
        }

        if isSolved {
            if isTimeTrialMode { stopTimeTrialCountdown() } else { stopCountdown() }
            stopStopwatch()
            if isDailyGameActive {
                if !debugOverlayEnabled {
                    let result = dailyChallengeStore.recordCompletion(moves: currentMoveCount, time: elapsedTime, date: dailyChallengeStore.effectiveDate)
                    isNewMovesRecord = result.isNewMovesRecord
                    isNewBestTime = result.isNewTimeRecord
                    isNewCalendarStreakRecord = result.isNewCalendarStreakRecord
                }
            } else if isZenMode {
                statsStore.recordGamePlayed(for: key)
            } else if !debugOverlayEnabled {
                // Ladder stages span every grid size in the table, so a stage clear must
                // NOT write into the per-size `StatsKey` Time Trial bests — that would
                // silently pollute, e.g., the single-puzzle 4×4 Time Trial player's record
                // with a Stage 3 ladder clear that happened to also be a 4×4.
                if !isGauntletLadderMode {
                    let result = statsStore.recordCompletion(for: key, moves: currentMoveCount, time: elapsedTime)
                    isNewMovesRecord = result.isNewMovesRecord
                    isNewBestTime = result.isNewBestTime
                }
                if isGauntletLadderMode {
                    let stage = GauntletLadderRules.stage(currentLadderStage)
                    let stageScore = GauntletLadderRules.stageScore(
                        remainingSeconds: timeTrialRemaining,
                        stage: stage,
                        currentWinStreak: ladderWinStreak
                    )
                    ladderCumulativeScore += stageScore
                    ladderWinStreak += 1
                    lastClearedLadderStage = currentLadderStage
                    isNewLadderStageRecord = statsStore.recordLadderStageReached(lastClearedLadderStage)
                    if currentLadderStage == GauntletLadderRules.stageCount {
                        isLadderRunComplete = true
                        isNewLadderScoreRecord = statsStore.recordLadderRunScore(ladderCumulativeScore)
                    } else {
                        currentLadderStage += 1
                    }
                } else if isTimeTrialMode {
                    let score = TimeTrialRules.score(remainingSeconds: timeTrialRemaining, gridSize: gridSize)
                    timeTrialScore = score
                    isNewTimeTrialScoreRecord = statsStore.recordTimeTrialScore(for: key, score: score)
                }
            }

            // Tracked across every mode (including Zen and Daily) whenever the game
            // isn't practice play — these back achievements unrelated to records/streaks.
            if !debugOverlayEnabled {
                if selectedGameMode != .slide && !hasHadWastedMoveThisGame {
                    statsStore.recordZeroWasteSolve()
                }
                // Daily always uses a seeded remote image, not the user's photo library.
                if !isDailyGameActive && mediaSourceType == .local {
                    statsStore.recordPhotoLibrarySolve()
                }
                statsStore.recordGameCompletedToday()
            }
        }

        if isTimeTrialMode {
            applyTimeTrialMoveOutcome(newlyCorrect: newlyCorrect)
        } else if isLimitedMovesMode {
            applyLimitedMovesBudgetCheck()
        } else if !isZenMode && !isDailyGameActive {
            if newlyCorrect > 0 {
                let result = statsStore.recordStreakIncrement(for: key, trackRecord: !debugOverlayEnabled)
                if !isSolved { startCountdown() }
                if result.isNewRecord { isNewRecord = true }
            } else {
                statsStore.resetStreak(for: key)
                isNewRecord = false
                stopCountdown()
            }
        }

        // Zen used to be excluded here too, which meant Zen-only achievements (e.g. a first
        // Zen clear) could never unlock. Practice/debug play is still excluded — it never
        // touches `StatsStore` records above, so it shouldn't unlock achievements either.
        if !debugOverlayEnabled {
            achievementsStore.checkAchievements(using: statsStore, justSolved: isSolved)
        }
        // The source image can't change mid-game, so only the cheap dynamic state needs
        // rewriting here — re-encoding the image JPEG on every tap was the old hot path.
        saveDynamicState()
    }

    /// Applies the flat combo bonus/misplay penalty to the running Time Trial countdown and
    /// fails the puzzle if that empties the clock. No-ops once already solved — the puzzle's
    /// final move shouldn't also be penalized/bonused after `stopTimeTrialCountdown()` above.
    private func applyTimeTrialMoveOutcome(newlyCorrect: Int) {
        guard !isSolved, let end = timeTrialEndDate else { return }

        let delta = newlyCorrect > 0 ? TimeTrialRules.comboBonusSeconds : -TimeTrialRules.misplayPenaltySeconds
        let newEnd = end.addingTimeInterval(delta)
        timeTrialEndDate = newEnd
        lastTimeTrialDelta = delta

        let remaining = newEnd.timeIntervalSinceNow
        timeTrialRemaining = max(0, remaining)
        if remaining <= 0 {
            isTimeTrialFailed = true
            if isGauntletLadderMode { isLadderRunFailed = true }
            stopTimeTrialCountdown()
        }
    }

    /// Fails the puzzle once the move budget is exhausted without solving. Checked after the
    /// solved branch above, so a move that both uses the last budgeted move and solves the
    /// puzzle counts as a win, not a simultaneous fail.
    private func applyLimitedMovesBudgetCheck() {
        guard !isSolved, currentMoveCount >= movesBudgetForCurrentSize else { return }
        isLimitedMovesFailed = true
    }

    func skipPreview() {
        previewSleepTask?.cancel()
        isPreviewing = false
    }

    /// Stops the countdown when the user quits mid-game; streak is preserved.
    func leaveGame() {
        if let backup = preDailyGameMode {
            selectedGameMode = backup
            preDailyGameMode = nil
        }
        if let backup = preQuickSnapGameMode {
            selectedGameMode = backup
            preQuickSnapGameMode = nil
        }
        isDailyGameActive = false
        isQuickSnapActive = false
        quickSnapImage = nil
        stopCountdown()
        stopTimeTrialCountdown()
        stopStopwatch()
        saveToUserDefaults()
    }
}

// MARK: - Configuration & current-size stats

extension GameSession {
    var difficultyLabel: String {
        switch gridSize {
        case 3: "Easy"
        case 4: "Medium"
        case 5: "Hard"
        case 6: "Expert"
        case 7: "Master"
        default: "Insane"
        }
    }

    var difficultyDisplayValue: String {
        useRandomSize ? "Random" : "\(difficultyLabel)  \(gridSize) × \(gridSize)"
    }

    var personalBestForCurrentSize: Int? { statsStore.personalBestMoves[currentStatsKey] }
    var personalBestTimeForCurrentSize: TimeInterval? { statsStore.personalBestTime[currentStatsKey] }
    var personalBestScoreForCurrentSize: Int? { statsStore.personalBestScore[currentStatsKey] }
    var currentStreakForCurrentSize: Int { statsStore.currentStreak[currentStatsKey] ?? 0 }
    var allTimeHighStreakForCurrentSize: Int { statsStore.allTimeHighStreak[currentStatsKey] ?? 0 }

    /// "If you solved right now" score, for the live HUD display during play — the final
    /// score recorded on solve uses the same formula at the moment `isSolved` flips.
    var timeTrialScoreEstimate: Int {
        TimeTrialRules.score(remainingSeconds: timeTrialRemaining, gridSize: gridSize)
    }

    var bestLadderScoreOverall: Int { statsStore.bestLadderScore }
    var bestLadderStageReachedOverall: Int { statsStore.bestLadderStageReached }

    /// Sets `gridSize`, clears any in-progress game (it was for a different size), and persists.
    func setGridSize(_ size: Int) {
        guard size != gridSize || useRandomSize else { return }
        useRandomSize = false
        gridSize = size
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        previewImage = nil
        isSolved = false
        isNewRecord = false
        defaults.set(false, forKey: Keys.useRandomSize)
        defaults.set(gridSize, forKey: Keys.gridSize)
        defaults.removeObject(forKey: Keys.tiles)
        defaults.removeObject(forKey: Keys.sourceImage)
    }

    func setRandomSize() {
        useRandomSize = true
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        previewImage = nil
        isSolved = false
        isNewRecord = false
        defaults.set(true, forKey: Keys.useRandomSize)
        defaults.removeObject(forKey: Keys.tiles)
        defaults.removeObject(forKey: Keys.sourceImage)
    }

    func setMediaSourceType(_ type: MediaSourceType) {
        guard type != mediaSourceType else { return }
        guard type != .numbers || selectedGameMode == .slide else { return }
        mediaSourceType = type
        defaults.set(type.rawValue, forKey: Keys.mediaSourceType)
    }

    /// Toggles the Gauntlet Ladder sub-mode of Time Trial. Enabling it immediately snaps
    /// `gridSize` to Stage 1's so any UI reading it before "Play" (e.g. the menu's
    /// Difficulty row) is already correct.
    func setLadderMode(_ enabled: Bool) {
        guard enabled != isLadderMode, isTimeTrialMode else { return }
        isLadderMode = enabled
        defaults.set(enabled, forKey: Keys.isLadderMode)
        if enabled {
            currentLadderStage = 1
            gridSize = GauntletLadderRules.stage(1).gridSize
        }
    }

    func setGameMode(_ mode: GameMode) {
        guard mode.isAvailable, mode != selectedGameMode else { return }
        selectedGameMode = mode
        defaults.set(mode.rawValue, forKey: Keys.gameMode)

        // Numbers media mode is Slide-only for now; fall back if it's no longer valid.
        if mediaSourceType == .numbers && mode != .slide {
            setMediaSourceType(.random)
        }
    }

    func resetConfiguration() {
        setGridSize(3)
        setMediaSourceType(.random)
        useRandomSize = false
        defaults.set(false, forKey: Keys.useRandomSize)
    }
}

// MARK: - Persistence

extension GameSession {
    enum Keys {
        static let gridSize = "puzzle.gridSize"
        static let mediaSourceType = "puzzle.mediaSourceType"
        static let tiles = "puzzle.tiles"
        static let sourceImage = "puzzle.sourceImage"
        static let currentMoveCount = "puzzle.currentMoveCount"
        static let elapsedTime = "puzzle.elapsedTime"
        static let useRandomSize = "puzzle.useRandomSize"
        static let gameMode = "puzzle.gameMode"
        static let timeTrialFailed = "puzzle.timeTrialFailed"
        static let limitedMovesFailed = "puzzle.limitedMovesFailed"
        static let isLadderMode = "puzzle.isLadderMode"
        static let currentLadderStage = "puzzle.currentLadderStage"
        static let ladderCumulativeScore = "puzzle.ladderCumulativeScore"
        static let ladderWinStreak = "puzzle.ladderWinStreak"
        static let hasHadWastedMoveThisGame = "puzzle.hasHadWastedMoveThisGame"
    }
}

// The two save entry points are `internal` (not `private`) so tests can assert the
// static/dynamic persistence split directly; the restore/codec helpers below stay private.
extension GameSession {
    /// Persists everything that changes during play — tiles, counters, mode/size, and the
    /// fail/ladder flags — but deliberately NOT the source image. The image is fixed for the
    /// life of a game, so re-encoding it to JPEG on every move (the previous behavior) was
    /// pure waste; this is the cheap save called after each move. `saveToUserDefaults()`
    /// layers the one-time image write on top for game start / restore-critical points.
    func saveDynamicState() {
        guard let tilesData = try? jsonEncoder.encode(tiles) else { return }
        defaults.set(tilesData, forKey: Keys.tiles)

        defaults.set(gridSize, forKey: Keys.gridSize)
        defaults.set(useRandomSize, forKey: Keys.useRandomSize)
        defaults.set(mediaSourceType.rawValue, forKey: Keys.mediaSourceType)
        defaults.set(selectedGameMode.rawValue, forKey: Keys.gameMode)
        defaults.set(currentMoveCount, forKey: Keys.currentMoveCount)
        defaults.set(elapsedTime, forKey: Keys.elapsedTime)
        defaults.set(isTimeTrialFailed, forKey: Keys.timeTrialFailed)
        defaults.set(isLimitedMovesFailed, forKey: Keys.limitedMovesFailed)
        defaults.set(isLadderMode, forKey: Keys.isLadderMode)
        defaults.set(currentLadderStage, forKey: Keys.currentLadderStage)
        defaults.set(ladderCumulativeScore, forKey: Keys.ladderCumulativeScore)
        defaults.set(ladderWinStreak, forKey: Keys.ladderWinStreak)
        defaults.set(hasHadWastedMoveThisGame, forKey: Keys.hasHadWastedMoveThisGame)
    }

    /// Full persist: the dynamic state plus the expensive source-image JPEG encode. Only
    /// needed when the image itself changes — i.e. once per new game — so it stays out of
    /// the per-move path. See `saveDynamicState()`.
    func saveToUserDefaults() {
        saveDynamicState()

        if let image = sourceImage, let jpegData = jpeg(from: image) {
            defaults.set(jpegData, forKey: Keys.sourceImage)
        }
    }
}

private extension GameSession {
    func restoreFromUserDefaults() {
        let savedSize = defaults.integer(forKey: Keys.gridSize)
        if (3...8).contains(savedSize) { gridSize = savedSize }
        useRandomSize = defaults.bool(forKey: Keys.useRandomSize)

        if let savedGameMode = defaults.string(forKey: Keys.gameMode).flatMap(GameMode.init(rawValue:)) {
            selectedGameMode = savedGameMode
        }

        if let rawSource = defaults.string(forKey: Keys.mediaSourceType),
           let savedSource = MediaSourceType(rawValue: rawSource) {
            mediaSourceType = savedSource
        }
        // Numbers media mode is Slide-only for now.
        if mediaSourceType == .numbers && selectedGameMode != .slide {
            mediaSourceType = .random
        }

        guard
            let tilesData = defaults.data(forKey: Keys.tiles),
            let restoredTiles = try? jsonDecoder.decode([TileModel].self, from: tilesData)
        else { return }

        guard restoredTiles.count == gridSize * gridSize else { return }

        if mediaSourceType == .numbers {
            tiles = restoredTiles
        } else {
            guard
                let imageData = defaults.data(forKey: Keys.sourceImage),
                let restoredImage = cgImage(fromJPEG: imageData)
            else { return }

            tiles = restoredTiles
            sourceImage = restoredImage
            let slicer = ImageSlicer()
            croppedSourceImage = slicer.centerCrop(restoredImage)
            let slices = slicer.slice(restoredImage, into: gridSize * gridSize)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })
        }

        isSolved = activeEngine.isSolved(tiles)
        currentMoveCount = defaults.integer(forKey: Keys.currentMoveCount)
        elapsedTime = defaults.double(forKey: Keys.elapsedTime)
        isTimeTrialFailed = defaults.bool(forKey: Keys.timeTrialFailed)
        isLimitedMovesFailed = defaults.bool(forKey: Keys.limitedMovesFailed)
        isLadderMode = defaults.bool(forKey: Keys.isLadderMode)
        currentLadderStage = defaults.integer(forKey: Keys.currentLadderStage)
        if currentLadderStage < 1 || currentLadderStage > GauntletLadderRules.stageCount { currentLadderStage = 1 }
        ladderCumulativeScore = defaults.integer(forKey: Keys.ladderCumulativeScore)
        ladderWinStreak = defaults.integer(forKey: Keys.ladderWinStreak)
        hasHadWastedMoveThisGame = defaults.bool(forKey: Keys.hasHadWastedMoveThisGame)
        if !isSolved && currentStreakForCurrentSize > 0 { startCountdown() }
        // Resuming restarts the Time Trial countdown at the full base duration rather than
        // the exact persisted remainder — background/foreground interruption handling is a
        // deliberately deferred follow-up, so this is an accepted MVP limitation. A puzzle
        // that had already failed stays failed rather than getting a fresh clock.
        if !isSolved && !isTimeTrialFailed && isTimeTrialMode { startTimeTrialCountdown() }
        // Resume the stopwatch only if it had actually started (i.e. a move was already made);
        // otherwise it should still wait for the first move, same as a fresh game.
        if !isSolved && currentMoveCount > 0 { startStopwatch() }
    }

    func jpeg(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, "public.jpeg" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        return CGImageDestinationFinalize(destination) ? (data as Data) : nil
    }

    func cgImage(fromJPEG data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
