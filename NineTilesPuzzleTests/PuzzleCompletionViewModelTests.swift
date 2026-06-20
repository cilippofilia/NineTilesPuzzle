//
//  PuzzleCompletionViewModelTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 6/19/26.
//

import CoreGraphics
import Testing
@testable import NineTilesPuzzle

@Suite("PuzzleCompletionViewModel")
@MainActor
struct PuzzleCompletionViewModelTests {

    // MARK: - Completion banner

    @Test func solvedChangeShowsCompletionAndCallsOnSolved() {
        let vm = PuzzleCompletionViewModel()
        var onSolvedCalled = false
        vm.handleSolvedChange(true, onSolved: { onSolvedCalled = true })
        #expect(vm.showCompletion)
        #expect(onSolvedCalled)
    }

    @Test func unsolvedChangeHidesCompletionWithoutCallingOnSolved() {
        let vm = PuzzleCompletionViewModel()
        var onSolvedCalled = false
        vm.handleSolvedChange(false, onSolved: { onSolvedCalled = true })
        #expect(!vm.showCompletion)
        #expect(!onSolvedCalled)
    }

    @Test func recordChangeHandlersSetTheirOwnFlags() {
        let vm = PuzzleCompletionViewModel()
        vm.handleNewRecordChange(true)
        vm.handleNewMovesRecordChange(true)
        vm.handleNewBestTimeChange(true)
        #expect(vm.showNewRecord)
        #expect(vm.showNewMovesRecord)
        #expect(vm.showNewBestTime)

        vm.handleNewRecordChange(false)
        #expect(!vm.showNewRecord)
        #expect(vm.showNewMovesRecord)
    }

    @Test func clearRecordFlagsIsANoOpWhenNotSolved() async {
        let vm = PuzzleCompletionViewModel()
        vm.handleNewRecordChange(true)
        vm.handleNewMovesRecordChange(true)

        await vm.clearRecordFlagsAfterDelay(isSolved: false)

        #expect(vm.showNewRecord)
        #expect(vm.showNewMovesRecord)
    }

    @Test func clearRecordFlagsAfterDelayClearsAllThreeFlags() async {
        let vm = PuzzleCompletionViewModel()
        vm.handleNewRecordChange(true)
        vm.handleNewMovesRecordChange(true)
        vm.handleNewBestTimeChange(true)

        await vm.clearRecordFlagsAfterDelay(isSolved: true)

        #expect(!vm.showNewRecord)
        #expect(!vm.showNewMovesRecord)
        #expect(!vm.showNewBestTime)
    }

    @Test func hasNewBestBadgeForNonSlideModesIgnoresTime() {
        let vm = PuzzleCompletionViewModel()
        vm.handleNewBestTimeChange(true)
        #expect(!vm.hasNewBestBadge(selectedGameMode: .classic))

        vm.handleNewMovesRecordChange(true)
        #expect(vm.hasNewBestBadge(selectedGameMode: .classic))
    }

    @Test func hasNewBestBadgeForSlideModeIncludesTime() {
        let vm = PuzzleCompletionViewModel()
        vm.handleNewBestTimeChange(true)
        #expect(vm.hasNewBestBadge(selectedGameMode: .slide))
    }

    @Test func hasNewBestBadgeForTimeTrialModeIncludesScoreRecord() {
        let vm = PuzzleCompletionViewModel()
        #expect(!vm.hasNewBestBadge(selectedGameMode: .timeTrial))

        vm.handleNewTimeTrialScoreRecordChange(true)
        #expect(vm.hasNewBestBadge(selectedGameMode: .timeTrial))
        // A Time Trial score record shouldn't leak into other modes' badge visibility.
        #expect(!vm.hasNewBestBadge(selectedGameMode: .classic))
    }

    @Test func clearRecordFlagsAfterDelayAlsoClearsTimeTrialScoreRecord() async {
        let vm = PuzzleCompletionViewModel()
        vm.handleNewTimeTrialScoreRecordChange(true)

        await vm.clearRecordFlagsAfterDelay(isSolved: true)

        #expect(!vm.showNewTimeTrialScoreRecord)
    }

    @Test func hasNewBestBadgeForTimeTrialModeIncludesLadderRecords() {
        let vm = PuzzleCompletionViewModel()
        #expect(!vm.hasNewBestBadge(selectedGameMode: .timeTrial))

        vm.handleNewLadderScoreRecordChange(true)
        #expect(vm.hasNewBestBadge(selectedGameMode: .timeTrial))
        #expect(!vm.hasNewBestBadge(selectedGameMode: .classic))

        vm.handleNewLadderScoreRecordChange(false)
        vm.handleNewLadderStageRecordChange(true)
        #expect(vm.hasNewBestBadge(selectedGameMode: .timeTrial))
    }

    @Test func clearRecordFlagsAfterDelayAlsoClearsLadderRecords() async {
        let vm = PuzzleCompletionViewModel()
        vm.handleNewLadderScoreRecordChange(true)
        vm.handleNewLadderStageRecordChange(true)

        await vm.clearRecordFlagsAfterDelay(isSolved: true)

        #expect(!vm.showNewLadderScoreRecord)
        #expect(!vm.showNewLadderStageRecord)
    }

    // MARK: - Time Trial fail overlay

    @Test func handleTimeTrialFailedChangeSetsShowTimeTrialFail() {
        let vm = PuzzleCompletionViewModel()
        vm.handleTimeTrialFailedChange(true)
        #expect(vm.showTimeTrialFail)

        vm.handleTimeTrialFailedChange(false)
        #expect(!vm.showTimeTrialFail)
    }

    @Test func prepareForNewGameClearsTimeTrialFail() {
        let vm = PuzzleCompletionViewModel()
        vm.handleTimeTrialFailedChange(true)
        vm.prepareForNewGame()
        #expect(!vm.showTimeTrialFail)
    }

    // MARK: - Banner drag-to-dismiss

    @Test func updateBannerDragTracksTranslation() {
        let vm = PuzzleCompletionViewModel()
        vm.updateBannerDrag(CGSize(width: 12, height: -4))
        #expect(vm.bannerOffset == CGSize(width: 12, height: -4))
    }

    @Test func endBannerDragSnapsBackToZero() {
        let vm = PuzzleCompletionViewModel()
        vm.updateBannerDrag(CGSize(width: 50, height: 50))
        vm.endBannerDrag()
        #expect(vm.bannerOffset == .zero)
    }

    @Test func prepareForNewGameResetsBannerOffset() {
        let vm = PuzzleCompletionViewModel()
        vm.updateBannerDrag(CGSize(width: 50, height: 50))
        vm.prepareForNewGame()
        #expect(vm.bannerOffset == .zero)
    }

    // MARK: - Zen completion sequence

    @Test func zenSequenceNoOpsWhenNotSolved() async {
        let vm = PuzzleCompletionViewModel()
        var onCompleteCalled = false
        await vm.runZenCompletionSequence(isZenMode: true, isSolved: { false }, onComplete: { onCompleteCalled = true })
        #expect(!onCompleteCalled)
        #expect(vm.zenBreathScale == 1)
        #expect(vm.zenGlowOpacity == 0)
    }

    @Test func zenSequenceNoOpsWhenNotZenMode() async {
        let vm = PuzzleCompletionViewModel()
        var onCompleteCalled = false
        await vm.runZenCompletionSequence(isZenMode: false, isSolved: { true }, onComplete: { onCompleteCalled = true })
        #expect(!onCompleteCalled)
    }

    @Test func zenSequenceBreathesAndCallsOnCompleteWhenStillSolved() async {
        let vm = PuzzleCompletionViewModel()
        var onCompleteCalled = false
        await vm.runZenCompletionSequence(isZenMode: true, isSolved: { true }, onComplete: { onCompleteCalled = true })
        #expect(onCompleteCalled)
        // Sequence ends back at rest, ready for the next puzzle's reveal.
        #expect(vm.zenBreathScale == 1)
        #expect(vm.zenGlowOpacity == 0)
    }

    @Test func zenSequenceStopsEarlyIfNoLongerSolvedMidway() async {
        let vm = PuzzleCompletionViewModel()
        var checkCount = 0
        var onCompleteCalled = false
        // True for the initial guard, then false on every subsequent check (simulating the
        // player quitting or the puzzle resetting partway through the breathing sequence).
        await vm.runZenCompletionSequence(
            isZenMode: true,
            isSolved: {
                checkCount += 1
                return checkCount == 1
            },
            onComplete: { onCompleteCalled = true }
        )
        #expect(!onCompleteCalled)
    }
}
