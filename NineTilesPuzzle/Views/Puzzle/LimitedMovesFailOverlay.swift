//
//  LimitedMovesFailOverlay.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// The Limited Moves fail overlay shown when the move budget runs out before the puzzle is
/// solved. Mirrors `TimeTrialFailOverlay`'s shape with a simpler move-count summary.
struct LimitedMovesFailOverlay: View {
    @Environment(GameSession.self) private var session

    let completion: PuzzleCompletionViewModel
    let onTryAgain: () -> Void

    var body: some View {
        PuzzleFailOverlayView(isShowing: completion.showLimitedMovesFail, onTryAgain: onTryAgain) {
            LimitedMovesFailView(
                moveCount: session.currentMoveCount,
                personalBestMoves: session.personalBestForCurrentSize
            )
        }
    }
}
