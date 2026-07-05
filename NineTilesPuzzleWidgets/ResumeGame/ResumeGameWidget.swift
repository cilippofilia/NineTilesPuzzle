//
//  ResumeGameWidget.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import SwiftUI
import WidgetKit

struct ResumeGameEntry: TimelineEntry {
    let date: Date
    /// The in-progress game to advertise, or `nil` for the "start a new puzzle" state.
    let resume: WidgetSnapshot.ResumeState?
}

struct ResumeGameProvider: TimelineProvider {
    /// A save older than this is treated as abandoned rather than nagging forever.
    private static let staleAfter: TimeInterval = 14 * 24 * 60 * 60

    func placeholder(in context: Context) -> ResumeGameEntry {
        ResumeGameEntry(date: .now, resume: sampleResume)
    }

    func getSnapshot(in context: Context, completion: @escaping (ResumeGameEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ResumeGameEntry>) -> Void) {
        // The in-progress game only changes through the app, which reloads this kind at
        // game start/leave/background/finish — a single non-expiring entry is the timeline.
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> ResumeGameEntry {
        var resume = WidgetDataStore.load()?.resume
        if let saved = resume?.savedAt, Date.now.timeIntervalSince(saved) > Self.staleAfter {
            resume = nil
        }
        return ResumeGameEntry(date: .now, resume: resume)
    }

    /// Gallery/snapshot sample. The image name is deliberately unresolvable, so previews show
    /// `BoardThumbnail`'s puzzle-glyph fallback instead of reading the App Group container.
    private var sampleResume: WidgetSnapshot.ResumeState {
        WidgetSnapshot.ResumeState(
            boardImageName: nil,
            gameModeRaw: GameMode.slide.rawValue,
            displayTitle: "Slide",
            displayIcon: "hand.draw",
            gridSize: 4,
            moveCount: 23,
            elapsedTime: 96,
            progress: 0.62,
            savedAt: .now
        )
    }
}

struct ResumeGameWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.resumeGame, provider: ResumeGameProvider()) { entry in
            // Keeps the card dark-only regardless of iOS's per-widget light/dark appearance
            // setting — see the matching note on DailyChallengeWidget.
            ResumeGameWidgetView(entry: entry)
                .colorScheme(.dark)
        }
        .configurationDisplayName("Resume Puzzle")
        .description("Jump back into your unfinished puzzle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) {
    ResumeGameWidget()
} timeline: {
    ResumeGameEntry(
        date: .now,
        resume: WidgetSnapshot.ResumeState(
            boardImageName: nil,
            gameModeRaw: GameMode.swap.rawValue,
            displayTitle: "Daily Challenge",
            displayIcon: "calendar",
            gridSize: 5,
            moveCount: 31,
            elapsedTime: 154,
            progress: 0.4,
            savedAt: .now
        )
    )
    ResumeGameEntry(date: .now, resume: nil)
}

#Preview("Medium", as: .systemMedium) {
    ResumeGameWidget()
} timeline: {
    ResumeGameEntry(
        date: .now,
        resume: WidgetSnapshot.ResumeState(
            boardImageName: nil,
            gameModeRaw: GameMode.chaos.rawValue,
            displayTitle: "Chaos Mode",
            displayIcon: "tornado",
            gridSize: 6,
            moveCount: 58,
            elapsedTime: 312,
            progress: 0.75,
            savedAt: .now
        )
    )
    ResumeGameEntry(date: .now, resume: nil)
}
