//
//  CompletionComparisonTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 10/24/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("CompletionComparison")
@MainActor
struct CompletionComparisonTests {
    private func rows(
        mode: GameMode = .slide,
        isLadderMode: Bool = false,
        isLadderRunComplete: Bool = false,
        moves: Int = 207,
        time: TimeInterval = 98,
        score: Int = 0,
        ladderRunScore: Int = 0,
        ladderStage: Int = 0,
        bests: PersonalBestSnapshot?
    ) -> [CompletionStatRow] {
        let stats = CompletionComparison.GameStats(
            gameMode: mode,
            isLadderMode: isLadderMode,
            isLadderRunComplete: isLadderRunComplete,
            moveCount: moves,
            elapsedTime: time,
            timeTrialScore: score,
            ladderRunScore: ladderRunScore,
            ladderStage: ladderStage
        )
        return CompletionComparison.rows(for: stats, bests: bests)
    }

    // MARK: - Regular modes

    @Test func newBestTimeIsListedFirstWithPreviousBestAndDelta() {
        let result = rows(bests: PersonalBestSnapshot(moves: 184, time: 112))
        #expect(result.map(\.metric) == [.time, .moves])
        #expect(result[0].outcome == .newBest(previous: "1:52", delta: "−0:14"))
        #expect(result[0].caption == "was 1:52")
        #expect(result[0].progress == 1)
    }

    @Test func missedMovesShowsBestDeltaAndProgress() {
        let result = rows(bests: PersonalBestSnapshot(moves: 184, time: 112))
        let moves = try? #require(result.first { $0.metric == .moves })
        guard case .missed(let best, let delta, let progress) = moves?.outcome else {
            Issue.record("Expected a missed outcome")
            return
        }
        #expect(best == "184")
        #expect(delta == "+23")
        #expect(abs(progress - 184.0 / 207.0) < 0.0001)
        #expect(moves?.caption == "best 184")
    }

    @Test func firstSolveAtSizeIsANewBestWithNoPrevious() {
        let result = rows(bests: PersonalBestSnapshot())
        #expect(result.allSatisfy { $0.outcome == .newBest(previous: nil, delta: nil) })
        #expect(result[0].caption == "First record")
        #expect(result[0].delta == nil)
    }

    @Test func matchingTheBestIsATieNotANewBest() {
        let result = rows(moves: 30, time: 60, bests: PersonalBestSnapshot(moves: 30, time: 60))
        #expect(result.allSatisfy { $0.outcome == .tiedBest })
        #expect(result.map(\.metric) == [.moves, .time])
    }

    @Test func unrankedGamesShowValuesOnly() {
        let result = rows(bests: nil)
        #expect(result.allSatisfy { $0.outcome == .unranked })
        #expect(result.allSatisfy { $0.caption == nil && $0.delta == nil && $0.progress == nil })
    }

    // MARK: - Live rows

    @Test func liveRowsShowCurrentValuesBesideTheBests() {
        let result = CompletionComparison.liveRows(
            for: CompletionComparison.GameStats(
                gameMode: .slide, isLadderMode: false, moveCount: 42, elapsedTime: 75, timeTrialScore: 0, ladderRunScore: 0
            ),
            bests: PersonalBestSnapshot(moves: 184, time: 112)
        )
        #expect(result.map(\.metric) == [.moves, .time])
        #expect(result[0].value == "42")
        #expect(result[0].outcome == .reference(best: "184"))
        #expect(result[1].value == "1:15")
        #expect(result[1].outcome == .reference(best: "1:52"))
        #expect(result.allSatisfy { !$0.isNewBest && $0.progress == nil })
    }

    @Test func liveRowsWithNoBestYetOrUnrankedShowValuesOnly() {
        let noBest = CompletionComparison.liveRows(
            for: CompletionComparison.GameStats(
                gameMode: .swap, isLadderMode: false, moveCount: 3, elapsedTime: 10, timeTrialScore: 0, ladderRunScore: 0
            ),
            bests: PersonalBestSnapshot()
        )
        let unranked = CompletionComparison.liveRows(
            for: CompletionComparison.GameStats(
                gameMode: .swap, isLadderMode: false, moveCount: 3, elapsedTime: 10, timeTrialScore: 0, ladderRunScore: 0
            ),
            bests: nil
        )
        #expect((noBest + unranked).allSatisfy { $0.outcome == .unranked })
    }

    @Test func liveTimeTrialAndGauntletRows() {
        let timeTrial = CompletionComparison.liveRows(
            for: CompletionComparison.GameStats(
                gameMode: .timeTrial, isLadderMode: false, moveCount: 5, elapsedTime: 0, timeTrialScore: 1900, ladderRunScore: 0
            ),
            bests: PersonalBestSnapshot(score: 2400)
        )
        #expect(timeTrial.map(\.metric) == [.score, .moves])
        #expect(timeTrial[0].outcome == .reference(best: 2400.formattedScore))

        let gauntlet = CompletionComparison.liveRows(
            for: CompletionComparison.GameStats(
                gameMode: .timeTrial, isLadderMode: true, moveCount: 5, elapsedTime: 0, timeTrialScore: 0, ladderRunScore: 8900
            ),
            bests: PersonalBestSnapshot()
        )
        #expect(gauntlet.map(\.metric) == [.runScore])
        #expect(gauntlet[0].outcome == .unranked)
    }

    // MARK: - Time Trial

    @Test func timeTrialComparesScoreHigherIsBetter() {
        let result = rows(mode: .timeTrial, moves: 20, score: 5300, bests: PersonalBestSnapshot(moves: 18, score: 5000))
        #expect(result.map(\.metric) == [.score, .moves])
        #expect(result[0].outcome == .newBest(previous: 5000.formattedScore, delta: "+" + 300.formattedScore))
    }

    @Test func lowerTimeTrialScoreIsAMiss() {
        let result = rows(mode: .timeTrial, moves: 18, score: 4000, bests: PersonalBestSnapshot(moves: 18, score: 5000))
        guard case .missed(_, let delta, let progress) = result.first(where: { $0.metric == .score })?.outcome else {
            Issue.record("Expected a missed outcome")
            return
        }
        #expect(delta == "−" + 1000.formattedScore)
        #expect(progress == 0.8)
    }

    // MARK: - Gauntlet Ladder

    @Test func midRunScoreBelowRecordIsReferenceOnly() {
        let result = rows(
            mode: .timeTrial, isLadderMode: true, ladderRunScore: 8900, ladderStage: 3,
            bests: PersonalBestSnapshot(ladderRunScore: 21000, ladderStage: 7)
        )
        #expect(result.map(\.metric) == [.stage, .runScore])
        #expect(result[0].outcome == .reference(best: "7"))
        #expect(result[1].outcome == .reference(best: 21000.formattedScore))
    }

    @Test func clearingPastTheFurthestStageIsANewBest() {
        let result = rows(
            mode: .timeTrial, isLadderMode: true, ladderRunScore: 8900, ladderStage: 8,
            bests: PersonalBestSnapshot(ladderRunScore: 21000, ladderStage: 7)
        )
        #expect(result[0].metric == .stage)
        #expect(result[0].outcome == .newBest(previous: "7", delta: "+1"))
    }

    @Test func completedRunBelowRecordIsAMiss() {
        let result = rows(
            mode: .timeTrial, isLadderMode: true, isLadderRunComplete: true, ladderRunScore: 18000, ladderStage: 10,
            bests: PersonalBestSnapshot(ladderRunScore: 21000, ladderStage: 10)
        )
        guard case .missed = result.first(where: { $0.metric == .runScore })?.outcome else {
            Issue.record("Expected a missed outcome")
            return
        }
    }
}

@Suite("PuzzleSidePanelLayout")
struct PuzzleSidePanelLayoutTests {
    private func split(_ size: CGSize, fold: CGRect? = nil, regular: Bool = true) -> PuzzleSidePanelLayout.Split? {
        PuzzleSidePanelLayout.split(
            for: PuzzleSidePanelLayout.ContentGeometry(size: size, divisionFrame: fold),
            hasRegularSizeClasses: regular
        )
    }

    @Test func wideWindowWithoutAFoldSplitsEvenly() {
        let result = split(CGSize(width: 1194, height: 760))
        #expect(result == PuzzleSidePanelLayout.Split(boardTrailingInset: 597, panelWidth: 597))
    }

    @Test func boardEndsWhereTheFoldStartsAndThePanelBeginsWhereItEnds() {
        // An off-center fold, as on iPhone Duo when its vertical system bar narrows one side.
        let result = split(CGSize(width: 1500, height: 900), fold: CGRect(x: 820, y: 0, width: 30, height: 900))
        #expect(result == PuzzleSidePanelLayout.Split(boardTrailingInset: 680, panelWidth: 650))
    }

    @Test func horizontalOrOutOfBoundsFoldFallsBackToAnEvenSplit() {
        let size = CGSize(width: 1200, height: 800)
        let even = PuzzleSidePanelLayout.Split(boardTrailingInset: 600, panelWidth: 600)
        #expect(split(size, fold: CGRect(x: 0, y: 390, width: 1200, height: 20)) == even)
        #expect(split(size, fold: CGRect(x: 1250, y: 0, width: 20, height: 800)) == even)
    }

    @Test func portraitOrNearSquareWindowKeepsTheStackedLayout() {
        #expect(split(CGSize(width: 834, height: 1100)) == nil)
        #expect(split(CGSize(width: 900, height: 850)) == nil)
    }

    @Test func compactSizeClassKeepsTheStackedLayout() {
        #expect(split(CGSize(width: 900, height: 400), regular: false) == nil)
    }
}
