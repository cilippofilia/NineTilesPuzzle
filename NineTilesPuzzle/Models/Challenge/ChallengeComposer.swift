//
//  ChallengeComposer.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import CoreGraphics
import Foundation

/// Builds a `FriendChallenge` from an already-finished (or freshly configured) game's
/// values. Pure and stateless — minting a fresh id/seed and encoding the image is all that's
/// needed; there is no `GameSession` mode for *sending* a challenge (see the architecture
/// note in `GameSession.enterChallengeMode(with:)`).
enum ChallengeComposer {
    /// Returns `nil` only if `image` fails to JPEG-encode (should not happen in practice).
    static func makeChallenge(
        senderName: String,
        gameMode: GameMode,
        gridSize: Int,
        image: CGImage,
        senderMoves: Int,
        senderTime: TimeInterval,
        parentChallengeID: UUID? = nil
    ) -> FriendChallenge? {
        guard let imageData = ChallengeImageCodec.encode(image) else { return nil }
        return FriendChallenge(
            senderName: senderName,
            gameMode: gameMode,
            gridSize: gridSize,
            seed: UInt64.random(in: UInt64.min...UInt64.max),
            imageData: imageData,
            senderMoves: senderMoves,
            senderTime: senderTime,
            parentChallengeID: parentChallengeID
        )
    }
}
