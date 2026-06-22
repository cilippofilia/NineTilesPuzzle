//
//  LimitedMovesFailView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/22/26.
//

import SwiftUI

/// Limited Moves' "ran out the budget" overlay, shown instead of `CompletionBannerView`
/// when the move budget hits 0 before the puzzle is solved.
struct LimitedMovesFailView: View {
    let moveCount: Int
    let personalBestMoves: Int?

    var body: some View {
        VStack(spacing: 6) {
            Label("Out of Moves", systemImage: "arrow.left.arrow.right")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.red)

            Label("\(moveCount) moves used", systemImage: "arrow.left.arrow.right")
                .bold()

            if let best = personalBestMoves {
                Text("Best: \(best) moves")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    VStack(spacing: 20) {
        LimitedMovesFailView(moveCount: 12, personalBestMoves: 10)
        LimitedMovesFailView(moveCount: 24, personalBestMoves: nil)
    }
}
