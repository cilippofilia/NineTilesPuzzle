//
//  ChallengeStoreTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/8/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("ChallengeStore")
@MainActor
struct ChallengeStoreTests {
    private func makeChallenge(
        id: UUID = UUID(),
        senderName: String = "Filippo",
        gameMode: GameMode = .slide,
        gridSize: Int = 4,
        seed: UInt64 = 42,
        senderMoves: Int = 30,
        senderTime: TimeInterval = 60,
        parentChallengeID: UUID? = nil
    ) -> FriendChallenge {
        FriendChallenge(
            id: id,
            senderName: senderName,
            gameMode: gameMode,
            gridSize: gridSize,
            seed: seed,
            imageData: Data([0xFF, 0xD8, 0xFF]),
            senderMoves: senderMoves,
            senderTime: senderTime,
            parentChallengeID: parentChallengeID
        )
    }

    // MARK: - Codable round-trips

    @Test func friendChallengeRoundTripsThroughJSON() throws {
        let original = makeChallenge()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FriendChallenge.self, from: data)
        #expect(decoded == original)
    }

    @Test func challengeRecordRoundTripsThroughJSON() throws {
        var original = ChallengeRecord(
            id: UUID(), direction: .received, opponentName: "Alex", gameMode: .swap,
            gridSize: 5, seed: 7, creatorMoves: 20, creatorTime: 45, transport: .file
        )
        original.opponentMoves = 18
        original.outcome = .won
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChallengeRecord.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - determineOutcome truth table

    @Test func fewerMovesWins() {
        #expect(ChallengeStore.determineOutcome(yourMoves: 10, yourTime: 100, creatorMoves: 20, creatorTime: 50) == .won)
    }

    @Test func moreMovesLoses() {
        #expect(ChallengeStore.determineOutcome(yourMoves: 30, yourTime: 10, creatorMoves: 20, creatorTime: 50) == .lost)
    }

    @Test func tiedMovesBreakOnFasterTime() {
        #expect(ChallengeStore.determineOutcome(yourMoves: 20, yourTime: 40, creatorMoves: 20, creatorTime: 50) == .won)
    }

    @Test func tiedMovesBreakOnSlowerTime() {
        #expect(ChallengeStore.determineOutcome(yourMoves: 20, yourTime: 60, creatorMoves: 20, creatorTime: 50) == .lost)
    }

    @Test func fullTieIsTied() {
        #expect(ChallengeStore.determineOutcome(yourMoves: 20, yourTime: 50, creatorMoves: 20, creatorTime: 50) == .tied)
    }

    // MARK: - registerSent / registerReceived / recordCompletion

    @Test func registerSentAddsASentRecord() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge()
        store.registerSent(challenge, opponentLabel: "Alex", transport: .file)

        #expect(store.records.count == 1)
        #expect(store.records[0].direction == .sent)
        #expect(store.records[0].opponentName == "Alex")
        #expect(store.records[0].creatorMoves == challenge.senderMoves)
    }

    @Test func registerReceivedAddsAnUnplayedReceivedRecord() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge(senderName: "Alex")
        store.registerReceived(challenge, transport: .nearby)

        #expect(store.records.count == 1)
        #expect(store.records[0].direction == .received)
        #expect(store.records[0].opponentName == "Alex")
        #expect(store.records[0].outcome == nil)
    }

    @Test func registerReceivedIsIdempotentForTheSameChallengeID() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge()
        store.registerReceived(challenge, transport: .file)
        store.registerReceived(challenge, transport: .file)

        #expect(store.records.count == 1)
    }

    @Test func recordCompletionFillsOpponentResultAndOutcome() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge(senderMoves: 40, senderTime: 90)
        store.registerReceived(challenge, transport: .file)

        let outcome = store.recordCompletion(challengeID: challenge.id, moves: 25, time: 60)

        #expect(outcome == .won)
        #expect(store.records[0].opponentMoves == 25)
        #expect(store.records[0].opponentTime == 60)
        #expect(store.records[0].outcome == .won)
        #expect(store.records[0].playedAt != nil)
    }

    @Test func recordCompletionReturnsNilForUnknownChallengeID() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        #expect(store.recordCompletion(challengeID: UUID(), moves: 1, time: 1) == nil)
    }

    @Test func recordCompletionNeverAppliesToASentRecord() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge()
        store.registerSent(challenge, opponentLabel: "Alex", transport: .file)

        #expect(store.recordCompletion(challengeID: challenge.id, moves: 1, time: 1) == nil)
    }

    // MARK: - pendingChallenge reconstruction

    @Test func pendingChallengeReconstructsAnUnplayedReceivedRecord() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge(senderName: "Alex", gameMode: .limitedMoves, gridSize: 5, seed: 99)
        store.registerReceived(challenge, transport: .file)

        let reconstructed = store.pendingChallenge(for: store.records[0])

        #expect(reconstructed?.id == challenge.id)
        #expect(reconstructed?.senderName == "Alex")
        #expect(reconstructed?.gameMode == .limitedMoves)
        #expect(reconstructed?.gridSize == 5)
        #expect(reconstructed?.seed == 99)
        #expect(reconstructed?.imageData == challenge.imageData)
    }

    @Test func pendingChallengeReturnsNilOnceThePlayIsRecorded() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge()
        store.registerReceived(challenge, transport: .file)
        store.recordCompletion(challengeID: challenge.id, moves: 1, time: 1)

        #expect(store.pendingChallenge(for: store.records[0]) == nil)
    }

    @Test func pendingChallengeReturnsNilForASentRecord() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        let challenge = makeChallenge()
        store.registerSent(challenge, opponentLabel: "Alex", transport: .file)

        #expect(store.pendingChallenge(for: store.records[0]) == nil)
    }

    // MARK: - Persistence across instances

    @Test func historyPersistsAcrossInstances() {
        let backing = InMemoryPersistenceStore()
        let first = ChallengeStore(defaults: backing)
        first.registerSent(makeChallenge(), opponentLabel: "Alex", transport: .file)

        let second = ChallengeStore(defaults: backing)
        #expect(second.records.count == 1)
        #expect(second.records[0].opponentName == "Alex")
    }

    // MARK: - Counting helpers

    @Test func countByDirectionAndOutcome() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        store.registerSent(makeChallenge(), opponentLabel: "Alex", transport: .file)
        let won = makeChallenge(senderMoves: 40)
        store.registerReceived(won, transport: .file)
        store.recordCompletion(challengeID: won.id, moves: 10, time: 10)
        let lost = makeChallenge(senderMoves: 5)
        store.registerReceived(lost, transport: .file)
        store.recordCompletion(challengeID: lost.id, moves: 40, time: 10)

        #expect(store.count(direction: .sent) == 1)
        #expect(store.count(direction: .received) == 2)
        #expect(store.count(outcome: .won) == 1)
        #expect(store.count(outcome: .lost) == 1)
        #expect(store.playedReceivedCount == 2)
    }

    // MARK: - History cap

    @Test func historyIsPrunedPastTheCap() {
        let store = ChallengeStore(defaults: InMemoryPersistenceStore())
        for _ in 0..<(ChallengeStore.historyCap + 10) {
            store.registerSent(makeChallenge(), opponentLabel: "Alex", transport: .file)
        }
        #expect(store.records.count == ChallengeStore.historyCap)
    }

    // MARK: - eligibleGameModes

    @Test func eligibleGameModesExcludesZen() {
        #expect(!ChallengeStore.eligibleGameModes.contains(.zen))
        #expect(ChallengeStore.eligibleGameModes.contains(.slide))
        #expect(ChallengeStore.eligibleGameModes.contains(.timeTrial))
    }
}
