//
//  ChallengeOutcomeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// The win/lose/tied comparison shown on the completion banner after finishing a received
/// Challenge Friends puzzle, with a one-tap "Challenge Them Back" reply.
struct ChallengeOutcomeView: View {
    let outcome: ChallengeRecord.Outcome
    let opponentName: String
    let yourMoves: Int
    let yourTime: TimeInterval
    let opponentMoves: Int
    let opponentTime: TimeInterval
    var onRechallenge: (() -> Void)?

    private var headline: String {
        switch outcome {
        case .won: "You beat \(opponentName)!"
        case .lost: "\(opponentName) beat you!"
        case .tied: "You tied with \(opponentName)!"
        }
    }

    private var tint: Color {
        switch outcome {
        case .won: .green
        case .lost: .red
        case .tied: .orange
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        Duration.seconds(time).formatted(.time(pattern: .minuteSecond))
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(headline)
                .font(.headline)
                .foregroundStyle(tint)

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("You").font(.caption).foregroundStyle(.secondary)
                    Text("\(yourMoves) moves").font(.subheadline.bold())
                    Text(formattedTime(yourTime)).font(.caption)
                }
                Text("vs").font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 2) {
                    Text(opponentName).font(.caption).foregroundStyle(.secondary)
                    Text("\(opponentMoves) moves").font(.subheadline.bold())
                    Text(formattedTime(opponentTime)).font(.caption)
                }
            }

            if let onRechallenge {
                Button("Challenge Them Back", action: onRechallenge)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }
}

#Preview {
    ChallengeOutcomeView(
        outcome: .won, opponentName: "Alex", yourMoves: 24, yourTime: 58,
        opponentMoves: 30, opponentTime: 70, onRechallenge: {}
    )
    .padding()
}
