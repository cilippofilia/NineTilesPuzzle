//
//  CompletionBannerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct CompletionBannerView: View {
    let streak: Int
    let isNewRecord: Bool
    let moveCount: Int
    let isNewMovesRecord: Bool
    let personalBest: Int?

    private static let goldColor = Color(hue: 0.12, saturation: 0.9, brightness: 0.85)

    var body: some View {
        VStack(spacing: 6) {
            if isNewRecord {
                Label("New Record!", systemImage: "trophy.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
            }
            Text("Completed!")
                .font(.largeTitle)
                .bold()
            Label("\(streak)", systemImage: "flame.fill")
                .foregroundStyle(.orange)
                .bold()

            Divider()
                .padding(.vertical, 2)

            if isNewMovesRecord {
                Label("New Best! \(moveCount) moves", systemImage: "medal.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("\(moveCount) moves")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let best = personalBest, best != moveCount {
                    Text("Best: \(best)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    VStack(spacing: 20) {
        CompletionBannerView(streak: 7, isNewRecord: true, moveCount: 23, isNewMovesRecord: true, personalBest: nil)
        CompletionBannerView(streak: 3, isNewRecord: false, moveCount: 31, isNewMovesRecord: false, personalBest: 23)
        CompletionBannerView(streak: 0, isNewRecord: false, moveCount: 18, isNewMovesRecord: false, personalBest: nil)
    }
}
