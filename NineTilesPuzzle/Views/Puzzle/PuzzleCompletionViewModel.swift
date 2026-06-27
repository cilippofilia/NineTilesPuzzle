//
//  PuzzleCompletionViewModel.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import SwiftUI

/// Drives `PuzzleView`'s post-solve presentation: the completion banner's lifetime and
/// drag-to-dismiss gesture, how long new-record badges stay visible, and Zen mode's
/// breathe-and-fade transition into the next puzzle. Pure sequencing/timing logic with no
/// dependency on `GameSession` or any other store — callers pass in whatever live values
/// or callbacks a method needs, so this stays testable without constructing the rest of
/// the app's environment.
@MainActor
@Observable
final class PuzzleCompletionViewModel {
    var showCompletion = false
    var showNewRecord = false
    var showNewMovesRecord = false
    var showNewBestTime = false
    var showNewTimeTrialScoreRecord = false
    var showNewLadderScoreRecord = false
    var showNewLadderStageRecord = false
    var showTimeTrialFail = false
    var showLimitedMovesFail = false
    var bannerOffset: CGSize = .zero

    var zenBreathScale: CGFloat = 1
    var zenGlowOpacity: Double = 0
    var zenSparkles: [ZenSparkle] = ZenSparkle.makeCluster()

    // MARK: - Completion banner

    func handleSolvedChange(_ solved: Bool, onSolved: () -> Void) {
        if solved { onSolved() }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(solved ? 0.3 : 0)) {
            showCompletion = solved
        }
    }

    /// Mirrors every "new record" flag from the session in one animated update, so the view
    /// can react with a single `.onChange` rather than wiring up one handler per record type.
    func applyRecords(_ flags: PuzzleRecordFlags) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            showNewRecord = flags.isNewRecord
            showNewMovesRecord = flags.isNewMovesRecord
            showNewBestTime = flags.isNewBestTime
            showNewTimeTrialScoreRecord = flags.isNewTimeTrialScoreRecord
            showNewLadderScoreRecord = flags.isNewLadderScoreRecord
            showNewLadderStageRecord = flags.isNewLadderStageRecord
        }
    }

    /// New-record badges fade out a few seconds after a solve, independent of how long the
    /// banner itself (and the "Continue" button) stays on screen.
    func clearRecordFlagsAfterDelay(isSolved: Bool) async {
        guard isSolved else { return }
        try? await Task.sleep(for: .seconds(4))
        withAnimation(.easeInOut(duration: 0.35)) {
            showNewRecord = false
            showNewMovesRecord = false
            showNewBestTime = false
            showNewTimeTrialScoreRecord = false
            showNewLadderScoreRecord = false
            showNewLadderStageRecord = false
        }
    }

    func hasNewBestBadge(selectedGameMode: GameMode) -> Bool {
        showNewMovesRecord
            || (selectedGameMode == .slide && showNewBestTime)
            || (selectedGameMode == .timeTrial && showNewTimeTrialScoreRecord)
            || (selectedGameMode == .timeTrial && showNewLadderScoreRecord)
            || (selectedGameMode == .timeTrial && showNewLadderStageRecord)
    }

    // MARK: - Time Trial fail overlay

    /// Mirrors `handleSolvedChange`'s show/hide shape but for the "ran out the clock"
    /// overlay, which is mutually exclusive with the completion banner.
    func handleTimeTrialFailedChange(_ failed: Bool) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showTimeTrialFail = failed }
    }

    /// Mirrors `handleTimeTrialFailedChange`'s shape for Limited Moves' "ran out the
    /// budget" overlay, also mutually exclusive with the completion banner.
    func handleLimitedMovesFailedChange(_ failed: Bool) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showLimitedMovesFail = failed }
    }

    // MARK: - Banner drag-to-dismiss

    func updateBannerDrag(_ translation: CGSize) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            bannerOffset = translation
        }
    }

    func endBannerDrag() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bannerOffset = .zero
        }
    }

    /// Resets banner positioning before the next puzzle starts.
    func prepareForNewGame() {
        bannerOffset = .zero
        showTimeTrialFail = false
        showLimitedMovesFail = false
    }

    // MARK: - Zen mode completion sequence

    /// Zen mode has no banner or "Continue" button: the solved picture breathes gently in
    /// and out — one inhale, one exhale — and the next puzzle begins the moment it settles,
    /// with no further prompt needed. `isSolved` is re-read after each delay (rather than
    /// captured once) since the player may have already left or restarted.
    func runZenCompletionSequence(isZenMode: Bool, isSolved: @escaping () -> Bool, onComplete: () -> Void) async {
        guard isSolved(), isZenMode else {
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
        guard isSolved() else { return }
        withAnimation(.easeInOut(duration: 1.1)) {
            zenBreathScale = 1
            zenGlowOpacity = 0
        }
        try? await Task.sleep(for: .seconds(1.1))
        guard isSolved() else { return }
        onComplete()
    }
}
