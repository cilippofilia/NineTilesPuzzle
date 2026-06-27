//
//  ShareCardView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// The image rendered into the share sheet when a player exports a completed puzzle.
/// All data is passed as plain values — no `@Environment` — so `ImageRenderer` can
/// render this view outside of SwiftUI's environment chain.
struct ShareCardView: View {
    let image: CGImage
    let gridSize: Int
    let gameMode: GameMode
    let moveCount: Int
    let elapsedTime: TimeInterval
    let isDailyChallenge: Bool
    let dailyDate: Date
    let calendarStreak: Int

    // Fixed light palette — the card always renders light regardless of device color
    // scheme so every share destination sees an identical image.
    private let background     = Color(red: 0.98, green: 0.97, blue: 0.95)
    private let labelPrimary   = Color(red: 0.10, green: 0.10, blue: 0.12)
    private let labelSecondary = Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.5)

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                imageSection
                statsSection
            }
        }
        .frame(width: 400, height: 480)
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    // MARK: - Sections

    private var imageSection: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: 360, height: 360)
            .clipShape(.rect(cornerRadius: 4))
            .padding(.top, 20)
            .padding(.horizontal, 20)
    }

    private var puzzleGradient: LinearGradient {
        LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "puzzlepiece.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 16)
                    .rotationEffect(.degrees(-45))
                    .foregroundStyle(puzzleGradient)

                Text("Nine Tiles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(labelPrimary)

                Spacer()

                Text(modeChipLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(labelSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.08), in: .capsule)
            }

            Text(contextLine)
                .font(.system(size: 12))
                .foregroundStyle(labelSecondary)
                .padding(.bottom, 6)

            Divider()

            HStack(spacing: 16) {
                ShareStatBadge(value: moveCount.formatted(), icon: "arrow.left.arrow.right", tint: labelPrimary)
                ShareStatBadge(value: formattedTime, icon: "clock", tint: labelPrimary)

                if isDailyChallenge && calendarStreak > 0 {
                    Spacer()
                    ShareStatBadge(value: "\(calendarStreak)", icon: "flame.fill", tint: .orange)
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(height: 100)
    }

    // MARK: - Helpers

    private var modeChipLabel: String {
        isDailyChallenge ? "Daily Challenge" : gameMode.title
    }

    private var contextLine: String {
        let grid = "\(gridSize)×\(gridSize)"
        if isDailyChallenge {
            let dateStr = dailyDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            return "\(dateStr)  ·  \(grid)  ·  \(gameMode.title)"
        } else {
            return "\(grid) grid"
        }
    }

    private var formattedTime: String {
        Duration.seconds(elapsedTime).formatted(.time(pattern: .minuteSecond))
    }
}

// MARK: - Subviews

private struct ShareStatBadge: View {
    let value: String
    let icon: String
    var tint: Color = Color(red: 0.10, green: 0.10, blue: 0.12)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(tint.opacity(0.7))
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    let placeholder = ImageRenderer(content: LinearGradient(
        colors: [.purple, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .frame(width: 400, height: 400)).cgImage

    if let cgImage = placeholder {
        ShareCardView(
            image: cgImage,
            gridSize: 4,
            gameMode: .fog,
            moveCount: 23,
            elapsedTime: 94,
            isDailyChallenge: true,
            dailyDate: .now,
            calendarStreak: 3
        )
        .padding(40)
        .background(Color.gray.opacity(0.2))
    }
}
