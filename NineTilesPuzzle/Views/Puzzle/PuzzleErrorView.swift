//
//  PuzzleErrorView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleErrorView: View {
    let error: Error
    let isDailyStreakFrozen: Bool
    let onRetry: () -> Void
    let onSwitchToPhotos: () -> Void

    var body: some View {
        VStack {
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
            if case ImageSourceError.providerUnavailable = error {
                if isDailyStreakFrozen {
                    Label("Your streak is safe — it won't break because of this outage.", systemImage: "snowflake")
                        .font(.footnote)
                        .bold()
                        .foregroundStyle(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(colors: [.blue.opacity(0.18), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: .capsule
                        )
                        .padding(.top, 4)
                }
                Button("Switch to Photos", action: onSwitchToPhotos)
                    .buttonStyle(.borderedProminent)
                Button("Try again", action: onRetry)
            } else {
                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
