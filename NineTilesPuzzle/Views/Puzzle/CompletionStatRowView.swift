//
//  CompletionStatRowView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 10/24/26.
//

import SwiftUI

/// One stat in the wide-layout completion panel: this game's value, the personal best it's
/// measured against, the difference, and a bar showing how close it came. A new best is
/// highlighted in gold; a miss stays neutral rather than reading as a failure.
struct CompletionStatRowView: View {
    let row: CompletionStatRow

    private static let goldColor = Color(hue: 0.12, saturation: 0.9, brightness: 0.85)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(row.metric.title, systemImage: row.metric.icon)
                    .font(.footnote)
                    .bold()
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Spacer()

                if row.isNewBest {
                    Label("New Best", systemImage: "medal.fill")
                        .font(.footnote)
                        .bold()
                        .foregroundStyle(Self.goldColor)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(row.value)
                    .font(.largeTitle)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(row.isNewBest ? Self.goldColor : .primary)

                if let caption = row.caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let delta = row.delta {
                    Text(delta)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(row.isNewBest ? Self.goldColor : .secondary)
                }
            }

            if let progress = row.progress {
                ProgressView(value: progress)
                    .tint(row.isNewBest ? Self.goldColor : .secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding()
        .background {
            if row.isNewBest {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Self.goldColor.opacity(0.12))
                    .strokeBorder(Self.goldColor.opacity(0.35))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack {
        CompletionStatRowView(row: CompletionStatRow(
            metric: .time, value: "1:38", outcome: .newBest(previous: "1:52", delta: "−0:14")
        ))
        CompletionStatRowView(row: CompletionStatRow(
            metric: .moves, value: "207", outcome: .missed(best: "184", delta: "+23", progress: 0.89)
        ))
        CompletionStatRowView(row: CompletionStatRow(
            metric: .moves, value: "23", outcome: .newBest(previous: nil, delta: nil)
        ))
        CompletionStatRowView(row: CompletionStatRow(metric: .time, value: "0:41", outcome: .unranked))
    }
    .padding()
}
