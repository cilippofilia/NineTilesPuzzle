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
    /// The sender's name (received) or a free-text label the sender typed for the recipient (sent).
    let opponentName: String
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
