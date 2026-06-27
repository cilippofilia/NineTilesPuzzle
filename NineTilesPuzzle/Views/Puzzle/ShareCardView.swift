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

    // Fixed dark palette — the card always renders dark regardless of device color
    // scheme so every share destination sees an identical image.
    private let background    = Color(red: 0.10, green: 0.10, blue: 0.11)
    private let labelPrimary  = Color.white
    private let labelSecondary = Color(white: 1, opacity: 0.55)

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                imageSection
                statsSection
            }
        }
        .frame(width: 400, height: 500)
    }

    // MARK: - Sections

    private var imageSection: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .frame(width: 360, height: 360)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(white: 1, opacity: 0.08), lineWidth: 1)
            )
            .padding(.top, 20)
    }

    private var puzzleGradient: LinearGradient {
        LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
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
                    .background(Color(white: 1, opacity: 0.10), in: .capsule)
            }
            .padding(.top, 14)

            Text(contextLine)
                .font(.system(size: 12))
                .foregroundStyle(labelSecondary)
                .padding(.top, 3)

            Divider()
                .background(Color(white: 1, opacity: 0.08))
                .padding(.vertical, 10)

            HStack(spacing: 20) {
                ShareStatBadge(value: moveCount.formatted(), icon: "arrow.left.arrow.right")
                ShareStatBadge(value: formattedTime, icon: "clock")

                if isDailyChallenge && calendarStreak > 0 {
                    Spacer()
                    ShareStatBadge(value: "\(calendarStreak)", icon: "flame.fill", tint: .orange)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
    var tint: Color = .white

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
    }
}
