//
//  DailyChallengeCalendarView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import SwiftUI

/// Scrollable month-by-month history of daily-challenge completions, from the
/// first day the player ever completed through today. Opens scrolled to the
/// current month; each completed day shows that day's puzzle image, fetched from
/// the same date-seeded URL the challenge itself used. Tapping a completed day
/// zooms a rebuilt share card, matching the Wall of Fame, with a Replay button
/// below it that hands the day to `onReplay`.
struct DailyChallengeCalendarView: View {
    @Environment(DailyChallengeStore.self) private var dailyStore

    /// Starts a replay of the given day's challenge; provided by the menu, which
    /// owns the navigation path the puzzle is pushed onto.
    let onReplay: (Date) -> Void

    @State private var zoomedCardImage: CGImage?
    @State private var zoomedDay: Date?
    @State private var isPreparingCard = false
    @State private var showCardError = false
    @State private var cardTask: Task<Void, Never>?

    var body: some View {
        let today = dailyStore.effectiveDate
        let months = DailyCalendarMonth.months(
            from: dailyStore.firstCompletedDate ?? today,
            through: today
        )

        // ZStack lets the zoom overlay escape the ScrollView's coordinate space
        // and cover the full navigation content area, mirroring the Wall of Fame.
        ZStack {
            ScrollView {
                LazyVStack {
                    ForEach(months) { month in
                        DailyMonthGridView(month: month, today: today, onDayTap: showCard)
                    }
                }
                .padding(.horizontal)
            }
            // Initial offset only: open scrolled to the current (last) month, but
            // keep content top-aligned when the history is shorter than the screen.
            .defaultScrollAnchor(.bottom, for: .initialOffset)

            if isPreparingCard {
                ProgressView()
                    .controlSize(.large)
            }

            if zoomedCardImage != nil {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.3))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let image = zoomedCardImage, let day = zoomedDay {
                ZoomedCardOverlay(
                    cardImage: image,
                    title: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                    onDismiss: dismissCard
                ) {
                    VStack {
                        if dailyStore.record(for: day) == nil {
                            Text("No stats saved for this day yet — replay it to record them.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: .capsule)
                        }

                        Button("Replay", systemImage: "arrow.counterclockwise") {
                            zoomedCardImage = nil
                            zoomedDay = nil
                            onReplay(day)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                // Spring-scale in, but fade straight out: reversing the scale on
                // removal read as a half-hearted shrink and the spring's long
                // settling tail made the fade feel laggy.
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.88).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .navigationTitle("Daily Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only real record cards are share-worthy — a record-less day zooms the
            // bare puzzle image, which isn't a "Daily Challenge Card" to send anywhere.
            if let image = zoomedCardImage, let day = zoomedDay, dailyStore.record(for: day) != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: Image(decorative: image, scale: 3),
                        preview: SharePreview("Daily Challenge Card")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .alert("Couldn't Load Puzzle", isPresented: $showCardError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("That day's puzzle image couldn't be fetched. Check your connection and try again.")
        }
        .onDisappear {
            cardTask?.cancel()
        }
    }

    /// Fades the zoomed card out with a quick ease — snappier than reversing
    /// the springy zoom-in animation.
    private func dismissCard() {
        withAnimation(.easeOut(duration: 0.18)) {
            zoomedCardImage = nil
            zoomedDay = nil
        }
    }

    /// Rebuilds the day's share card — image, grid size, and mode all derive
    /// deterministically from the date; moves/time/streak come from the stored
    /// record — then zooms it exactly like a Wall of Fame card.
    ///
    /// Days completed before per-day records existed have no stats to rebuild a
    /// card from, so they zoom the day's puzzle image itself; replaying the day
    /// records stats and upgrades future taps to the full card.
    private func showCard(for day: Date) {
        guard !isPreparingCard else { return }
        isPreparingCard = true
        cardTask?.cancel()
        cardTask = Task {
            defer { isPreparingCard = false }
            guard let image = try? await DailyImageSource(date: day).fetchImage() else {
                if !Task.isCancelled { showCardError = true }
                return
            }

            let zoomImage: CGImage
            if let record = dailyStore.record(for: day) {
                let card = ShareCardView(
                    image: image,
                    gridSize: DailyChallengeSeeder.gridSize(for: day),
                    gameMode: DailyChallengeSeeder.gameMode(for: day),
                    moveCount: record.moves,
                    elapsedTime: record.time,
                    isDailyChallenge: true,
                    dailyDate: day,
                    calendarStreak: record.streak
                )
                let renderer = ImageRenderer(content: card)
                renderer.scale = 3.0
                guard let rendered = renderer.cgImage else { return }
                zoomImage = rendered
            } else {
                zoomImage = image
            }
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                zoomedCardImage = zoomImage
                zoomedDay = day
            }
        }
    }
}

#Preview {
    NavigationStack {
        DailyChallengeCalendarView(onReplay: { _ in })
            .environment(DailyChallengeStore())
    }
}
