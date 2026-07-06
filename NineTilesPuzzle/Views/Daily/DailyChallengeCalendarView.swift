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
/// with recorded stats zooms a rebuilt share card, matching the Wall of Fame.
struct DailyChallengeCalendarView: View {
    @Environment(DailyChallengeStore.self) private var dailyStore

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
            .defaultScrollAnchor(.bottom)

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
                    title: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                ) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        zoomedCardImage = nil
                        zoomedDay = nil
                    }
                }
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: zoomedCardImage == nil)
        .navigationTitle("Daily Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let image = zoomedCardImage {
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

    /// Rebuilds the day's share card — image, grid size, and mode all derive
    /// deterministically from the date; moves/time/streak come from the stored
    /// record — then zooms it exactly like a Wall of Fame card.
    private func showCard(for day: Date) {
        guard let record = dailyStore.record(for: day), !isPreparingCard else { return }
        isPreparingCard = true
        cardTask?.cancel()
        cardTask = Task {
            defer { isPreparingCard = false }
            guard let image = try? await DailyImageSource(date: day).fetchImage() else {
                if !Task.isCancelled { showCardError = true }
                return
            }

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
            guard let rendered = renderer.cgImage, !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                zoomedCardImage = rendered
                zoomedDay = day
            }
        }
    }
}

#Preview {
    NavigationStack {
        DailyChallengeCalendarView()
            .environment(DailyChallengeStore())
    }
}
