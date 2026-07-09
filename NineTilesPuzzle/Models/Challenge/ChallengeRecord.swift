//
//  ChallengeRecord.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import Foundation

/// The local history entry `ChallengeStore` persists for one `FriendChallenge` — either one
/// this device sent, or one it received (and may or may not have played yet). Naming is
/// deliberately direction-agnostic (`creatorMoves`/`opponentMoves` rather than "yours"/
/// "theirs") because for a `.sent` record *this device* is the creator.
nonisolated struct ChallengeRecord: Codable, Equatable, Identifiable, Sendable {
    enum Direction: String, Codable {
        case sent
        case received
    }

    enum Outcome: String, Codable {
        case won
        case lost
        case tied
    }

    enum Transport: String, Codable {
        case file
        case nearby
    }

    let id: UUID
    let direction: Direction
    /// The sender's name (received), or a free-text label the sender typed for the recipient
    /// (sent) — upgraded to the recipient's real name once their `ChallengeResult` reply
    /// arrives, via `ChallengeStore.recordOpponentResult`.
    var opponentName: String
    let gameMode: GameMode
    let gridSize: Int
    let seed: UInt64
    let creatorMoves: Int
    let creatorTime: TimeInterval
    var opponentMoves: Int?
    var opponentTime: TimeInterval?
    var outcome: Outcome?
    let createdAt: Date
    var playedAt: Date?
    let transport: Transport
    let parentChallengeID: UUID?

    init(
        id: UUID,
        direction: Direction,
        opponentName: String,
        gameMode: GameMode,
        gridSize: Int,
        seed: UInt64,
        creatorMoves: Int,
        creatorTime: TimeInterval,
        opponentMoves: Int? = nil,
        opponentTime: TimeInterval? = nil,
        outcome: Outcome? = nil,
        createdAt: Date = .now,
        playedAt: Date? = nil,
        transport: Transport,
        parentChallengeID: UUID? = nil
    ) {
        self.id = id
        self.direction = direction
        self.opponentName = opponentName
        self.gameMode = gameMode
        self.gridSize = gridSize
        self.seed = seed
        self.creatorMoves = creatorMoves
        self.creatorTime = creatorTime
        self.opponentMoves = opponentMoves
        self.opponentTime = opponentTime
        self.outcome = outcome
        self.createdAt = createdAt
        self.playedAt = playedAt
        self.transport = transport
        self.parentChallengeID = parentChallengeID
    }
}

extension ChallengeRecord {
    /// Alert title for the moment an opponent's `ChallengeResult` reply lands on the device
    /// that originally sent this challenge — only meaningful once `outcome` is set.
    var resultAlertTitle: String {
        switch outcome {
        case .won: "You Won!"
        case .lost: "You Lost"
        case .tied: "It's a Tie!"
        case nil: ""
        }
    }

    /// Companion message for `resultAlertTitle`, summarizing the move counts on both sides.
    var resultAlertMessage: String {
        guard let outcome, let opponentMoves else { return "" }
        return switch outcome {
        case .won:
            "\(opponentName) played your challenge — you beat them \(creatorMoves) moves to \(opponentMoves)!"
        case .lost:
            "\(opponentName) played your challenge and beat you \(opponentMoves) moves to \(creatorMoves)."
        case .tied:
            "\(opponentName) played your challenge and tied you at \(creatorMoves) moves!"
        }
    }
}
