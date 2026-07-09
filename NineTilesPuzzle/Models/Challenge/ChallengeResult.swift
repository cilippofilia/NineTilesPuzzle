//
//  ChallengeResult.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/9/26.
//

import Foundation

/// The reply half of a Challenge Friends round trip: sent back by whoever played a received
/// `FriendChallenge`, so the original sender's `.sent` history record can learn the outcome.
/// Deliberately tiny (no image, no mode/grid/seed) since the receiver already has all of that
/// from the original challenge — only the played result needs to travel back.
nonisolated struct ChallengeResult: Codable, Equatable, Sendable {
    /// Matches the `FriendChallenge.id` this is a reply to — which is also the id of both the
    /// sender's `.sent` record and the responder's `.received` record.
    let challengeID: UUID
    let responderName: String
    let moves: Int
    let time: TimeInterval
}
