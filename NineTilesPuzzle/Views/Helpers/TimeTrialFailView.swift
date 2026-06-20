//
//  TimeTrialFailView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/20/26.
//

import SwiftUI

/// Time Trial's "ran out the clock" overlay, shown instead of `CompletionBannerView` when
/// the countdown reaches zero before the puzzle is solved. The score is always 0 in this
/// case (the MVP formula only rewards remaining time, no partial credit), so this leads
/// with move count instead to still give the player something concrete to read.
struct TimeTrialFailView: View {
    let moveCount: Int
    let personalBestScore: Int?

    var body: some View {
        VStack(spacing: 6) {
            Label("Out of Time", systemImage: "timer")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.red)

            Label("\(moveCount) moves", systemImage: "arrow.left.arrow.right")
                .bold()

            if let best = personalBestScore {
                Text("Best Score: \(best)")
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
        TimeTrialFailView(moveCount: 14, personalBestScore: 4200)
        TimeTrialFailView(moveCount: 3, personalBestScore: nil)
    }
}
