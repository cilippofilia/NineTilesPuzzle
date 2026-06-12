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
    let isPracticeMode: Bool

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

            if !isPracticeMode {
                HStack(spacing: 20) {
                    Label("\(streak)", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                        .bold()

                    Label("\(moveCount) moves", systemImage: "arrow.left.arrow.right")
                }

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
        .overlay(alignment: .bottom) {
            if isNewMovesRecord {
                Label("New Best! \(moveCount) moves", systemImage: "medal.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Self.goldColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .clipShape(.capsule)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .offset(y: 42)

            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CompletionBannerView(
            streak: 7,
            isNewRecord: true,
            moveCount: 23,
            isNewMovesRecord: true,
            personalBest: nil,
            isPracticeMode: false
        )
        Spacer()
        CompletionBannerView(
            streak: 3,
            isNewRecord: false,
            moveCount: 31,
            isNewMovesRecord: false,
            personalBest: 23,
            isPracticeMode: false
        )
        Spacer()
        CompletionBannerView(
            streak: 0,
            isNewRecord: false,
            moveCount: 18,
            isNewMovesRecord: false,
            personalBest: nil,
            isPracticeMode: true
        )
    }
}
