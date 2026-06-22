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
    private let defaults: PersistenceStore

    private let classicEngine = ClassicEngine()
    private let slideEngine = SlideEngine()
    private var previewSleepTask: Task<Void, Never>?

    var gridSize: Int = 3
    var useRandomSize: Bool = false
    var mediaSourceType: MediaSourceType = .random
    var tiles: [TileModel] = []
    var tileImages: [Int: CGImage] = [:]
    var sourceImage: CGImage?
    /// The center-cropped square `sourceImage` is sliced from — what tiles actually show,
    /// used to reveal the complete picture on solve without a mismatched, uncropped edge.
    var croppedSourceImage: CGImage?
    var isLoading = false
    var isPreviewing = false
    var isSolved = false
    var isNewRecord: Bool = false
    var currentMoveCount: Int = 0
    var isNewMovesRecord: Bool = false
    var elapsedTime: TimeInterval = 0
    var isNewBestTime: Bool = false
    var error: Error?
    var selectedGameMode: GameMode = .classic
    var isNewTimeTrialScoreRecord: Bool = false
    var timeTrialScore: Int = 0

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
            return classicEngine
        }
    }

    init(
        statsStore: StatsStore,
        achievementsStore: AchievementsStore,
        settingsStore: SettingsStore,
        defaults: PersistenceStore = UserDefaults.standard
    ) {
        self.statsStore = statsStore
        self.achievementsStore = achievementsStore
        self.settingsStore = settingsStore
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

    /// Fetches a fresh image, slices it, shuffles the tiles, and persists state. In `.numbers`
    /// media mode there is no image to fetch or preview — tiles are shuffled immediately.
    func startNewGame() async {
        // The Ladder dictates its own grid size per stage; this must win over `useRandomSize`
        // in case a stale `true` is left over from before the player entered Ladder mode.
        if isGauntletLadderMode {
            gridSize = GauntletLadderRules.stage(currentLadderStage).gridSize
        } else if useRandomSize {
            gridSize = Int.random(in: 3...8)
        }
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
        isLoading = true
        isSolved = false
        isNewRecord = false
        currentMoveCount = 0
        isNewMovesRecord = false
        elapsedTime = 0
        isNewBestTime = false
        isNewTimeTrialScoreRecord = false
        timeTrialScore = 0
        isLadderRunComplete = false
        isNewLadderScoreRecord = false
        isNewLadderStageRecord = false
        isLimitedMovesFailed = false
        // Otherwise this stays stuck from a previous Time Trial run that ended in failure —
        // `startTimeTrialCountdown()` only resets it when re-entering Time Trial itself, so
        // every other mode's `swapTiles` (which guards on this flag regardless of mode)
        // would silently block every move forever afterward.
        isTimeTrialFailed = false
        error = nil
        stopTimeTrialCountdown()

        let initial = (0..<gridSize * gridSize).map {
            TileModel(id: $0, currentIndex: $0, isLocked: false)
        }

        guard mediaSourceType != .numbers else {
            isLoading = false
            tiles = activeEngine.shuffle(initial, gridSize: gridSize)
            if currentStreakForCurrentSize > 0 { startCountdown() }
            if isTimeTrialMode { startTimeTrialCountdown() }
            saveToUserDefaults()
            return
        }

        do {
            let source: any ImageSource = switch mediaSourceType {
            case .local: PhotoLibraryImageSource()
            case .mixed: Bool.random() ? RemoteImageSource() : PhotoLibraryImageSource()
            default: RemoteImageSource() // covers .random; .numbers is handled above
            }
            let result = try await ImageService(primarySource: source).loadImage()
            let isRemote = source is RemoteImageSource && !result.usedFallback
            let image = result.image
            sourceImage = image

            let slicer = ImageSlicer()
            croppedSourceImage = slicer.centerCrop(image)
            let slices = slicer.slice(image, into: gridSize * gridSize)
            tileImages = Dictionary(uniqueKeysWithValues: slices.enumerated().map { ($0, $1) })

            isLoading = false

            if isRemote && settingsStore.previewDuration > 0 {
                isPreviewing = true
                previewSleepTask = Task { try? await Task.sleep(for: .seconds(settingsStore.previewDuration)) }
                await previewSleepTask?.value
                previewSleepTask = nil
                isPreviewing = false
            }

            tiles = activeEngine.shuffle(initial, gridSize: gridSize)
            if currentStreakForCurrentSize > 0 { startCountdown() }
            if isTimeTrialMode { startTimeTrialCountdown() }
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
        classicEngine.swap(&tiles, from: sourceIndex, to: targetIndex)
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

        if isSolved {
            if isTimeTrialMode { stopTimeTrialCountdown() } else { stopCountdown() }
            stopStopwatch()
            if isZenMode {
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
        }

        if isTimeTrialMode {
            applyTimeTrialMoveOutcome(correctBefore: correctBefore)
        } else if isLimitedMovesMode {
            applyLimitedMovesBudgetCheck()
        } else if !isZenMode {
            let newlyCorrect = tiles.filter { $0.isCorrect }.count - correctBefore
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

        if !isZenMode && !debugOverlayEnabled { achievementsStore.checkAchievements(using: statsStore) }
        saveToUserDefaults()
    }

    /// Applies the flat combo bonus/misplay penalty to the running Time Trial countdown and
    /// fails the puzzle if that empties the clock. No-ops once already solved — the puzzle's
    /// final move shouldn't also be penalized/bonused after `stopTimeTrialCountdown()` above.
    private func applyTimeTrialMoveOutcome(correctBefore: Int) {
        guard !isSolved, let end = timeTrialEndDate else { return }

        let newlyCorrect = tiles.filter { $0.isCorrect }.count - correctBefore
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

    /// Streaks only make sense in Classic mode (see `PuzzleStatusBarView`), so the menu's
    /// streak card always shows Classic's stats regardless of the currently selected mode.
    var classicBestMovesForCurrentSize: Int? {
        statsStore.personalBestMoves[StatsKey(gridSize: gridSize, gameMode: .classic)]
    }
    var classicStreakForCurrentSize: Int {
        statsStore.currentStreak[StatsKey(gridSize: gridSize, gameMode: .classic)] ?? 0
    }
    var classicBestStreakForCurrentSize: Int {
        statsStore.allTimeHighStreak[StatsKey(gridSize: gridSize, gameMode: .classic)] ?? 0
    }

    /// Sets `gridSize`, clears any in-progress game (it was for a different size), and persists.
    func setGridSize(_ size: Int) {
        guard size != gridSize || useRandomSize else { return }
        useRandomSize = false
        gridSize = size
        tiles = []
        tileImages = [:]
        sourceImage = nil
        croppedSourceImage = nil
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
    }
}

private extension GameSession {
    func saveToUserDefaults() {
        guard let tilesData = try? JSONEncoder().encode(tiles) else { return }
        defaults.set(tilesData, forKey: Keys.tiles)

        if let image = sourceImage, let jpegData = jpeg(from: image) {
            defaults.set(jpegData, forKey: Keys.sourceImage)
        }

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
    }

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
            let restoredTiles = try? JSONDecoder().decode([TileModel].self, from: tilesData)
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
