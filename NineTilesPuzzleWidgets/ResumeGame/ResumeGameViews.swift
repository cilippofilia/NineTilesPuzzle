//
//  ResumeGameViews.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import SwiftUI
import WidgetKit

/// Family switch for the Resume Puzzle widget. With a game in progress the whole widget
/// deep-links to the restored board; empty, a tap just opens the app to the menu.
struct ResumeGameWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ResumeGameEntry

    var body: some View {
        if let resume = entry.resume {
            Group {
                if family == .systemMedium {
                    ResumeGameMediumView(resume: resume)
                } else {
                    ResumeGameSmallView(resume: resume)
                }
            }
            .widgetURL(DeepLink.resume.url)
        } else {
            ResumeGameEmptyView()
        }
    }
}

/// Small card: the board fills the widget with the progress and move count overlaid below.
struct ResumeGameSmallView: View {
    let resume: WidgetSnapshot.ResumeState
    private let accent = Color.orange

    var body: some View {
        ResumeBoardThumbnail(imageName: resume.boardImageName, cornerRadius: 12)
            .overlay(alignment: .topTrailing) {
                ModeGlyphBadge(icon: resume.displayIcon, accent: accent, size: 22)
                    .offset(x: -8, y: 8)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    ProgressRing(progress: resume.progress, accent: accent, lineWidth: 3)
                        .frame(width: 18, height: 18)
                    Text("\(resume.moveCount) moves")
                        .font(.caption.bold().monospacedDigit())
                    Spacer(minLength: 0)
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(accent)
                }
                .widgetAccentable()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: .rect(cornerRadius: 10))
                .padding(6)
            }
            .containerBackground(for: .widget) { DailyWidgetBackground() }
    }
}

/// Medium card: board on the left, game identity and counters on the right.
struct ResumeGameMediumView: View {
    let resume: WidgetSnapshot.ResumeState
    private let accent = Color.orange

    var body: some View {
        HStack(spacing: 14) {
            ResumeBoardThumbnail(imageName: resume.boardImageName, cornerRadius: 14)
                .frame(width: 92, height: 92)
                .overlay(alignment: .bottomTrailing) {
                    ModeGlyphBadge(icon: resume.displayIcon, accent: accent, size: 22)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(resume.displayTitle) · \(resume.gridSize)×\(resume.gridSize)")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    StatBadge(icon: "arrow.left.arrow.right", text: "\(resume.moveCount)", accent: accent)
                    StatBadge(icon: "clock", text: resume.elapsedTime.formattedMinutesSeconds, accent: accent)
                    StatBadge(
                        icon: "chart.pie.fill",
                        text: resume.progress.formatted(.percent.precision(.fractionLength(0))),
                        accent: accent
                    )
                }
                .widgetAccentable()

                Text("Tap to keep solving")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { DailyWidgetBackground() }
    }
}

/// Shown when nothing is in progress: brand mark and an invitation, no deep link.
struct ResumeGameEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            BrandPuzzleMark(size: 36)
            Text("Start a new puzzle")
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            Text("Your unfinished game will appear here")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .widgetAccentable()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { DailyWidgetBackground() }
    }
}

/// The Resume widget's board image. A widget-local sibling of `BoardThumbnail` (which the
/// Live Activity keeps untouched) so the photo can opt into accented-mode desaturation —
/// otherwise a tinted Home Screen would blank the board entirely — and so a `nil` name
/// (numbers games have no picture) falls through to the same puzzle-glyph placeholder.
struct ResumeBoardThumbnail: View {
    let imageName: String?
    let cornerRadius: CGFloat

    var body: some View {
        content
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var content: some View {
        if let imageName,
           let url = LiveActivityStore.boardImageURL(named: imageName),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .scaledToFill()
        } else {
            ZStack {
                Color.black.opacity(0.4)
                Image(systemName: "puzzlepiece.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
