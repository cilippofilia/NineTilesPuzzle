//
//  DailyChallengeAltViews.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// A design-forward alternative to `DailyChallengeWidgetView`, built to sit side by side with
/// the original on a home screen for comparison. Same entry, same data — different visual
/// language: a glowing brand-gradient watermark, a calendar-page date chip, and gradient hero
/// numerals in place of plain labels and pills.
struct DailyChallengeAltWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyChallengeEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                DailyMediumAltView(entry: entry)
            default:
                DailySmallAltView(entry: entry)
            }
        }
        .widgetURL(DeepLink.daily.url)
    }
}

/// Small home-screen card: minimal wordmark header, a hero-sized grid readout (or solved seal),
/// and a Duolingo-style row of puzzle pieces marking the streak's recent days.
struct DailySmallAltView: View {
    let entry: DailyChallengeEntry
    private let accent = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DailyAltHeaderLabel()

            if entry.isCompletedToday {
                HStack(spacing: 8) {
                    SolvedSeal(size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Solved")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                        Text("Come back tomorrow")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    ModeIconChip(icon: entry.mode.icon, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(entry.gridSize)×\(entry.gridSize)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(BrandGradient.diagonal)
                        Text(entry.mode.title.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.6)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxHeight: .infinity)
            }

            StreakPieceRow(
                date: entry.date, streak: entry.streak, isCompletedToday: entry.isCompletedToday,
                accent: accent, maxCapacity: 5, pieceSize: 13, spacing: 3, showsWeekdayLabels: false
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { DailyAltBackground() }
    }
}

/// Medium home-screen card: a torn-calendar-page date chip and mode identity up top, a gradient
/// "Play" pill (or solved seal) alongside them, and a full-width Duolingo-style puzzle-piece
/// streak row — with weekday initials — anchoring the bottom.
struct DailyMediumAltView: View {
    let entry: DailyChallengeEntry
    private let accent = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                CalendarPageChip(date: entry.date)

                VStack(alignment: .leading, spacing: 6) {
                    DailyAltHeaderLabel()
                    HStack(spacing: 8) {
                        ModeIconChip(icon: entry.mode.icon, size: 26)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.mode.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("\(entry.gridSize) × \(entry.gridSize) grid")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                        if entry.isCompletedToday {
                            SolvedSeal(size: 34)
                        } else {
                            PlayCTAButton()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

//                if entry.isCompletedToday {
//                    SolvedSeal(size: 34)
//                } else {
//                    PlayCTAButton()
//                }
            }

            StreakPieceRow(
                date: entry.date, streak: entry.streak, isCompletedToday: entry.isCompletedToday,
                accent: accent, maxCapacity: 9, pieceSize: 18, spacing: 16, showsWeekdayLabels: true,
                alignment: .leading
            )
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { DailyAltBackground(markOffsetX: 70) }
    }
}

/// Shared red→yellow brand gradient used across the alt widgets' hero elements.
private enum BrandGradient {
    static let diagonal = LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
}

/// A minimal wordmark header — brand glyph plus tracked-out "DAILY" — used in place of the
/// original's material pill for a leaner, more editorial top edge.
private struct DailyAltHeaderLabel: View {
    var body: some View {
        HStack(spacing: 4) {
            BrandPuzzleMark(size: 14)
            Text("DAILY PUZZLE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1.4)
                .foregroundStyle(.secondary)
        }
        .widgetAccentable()
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(.capsule(style: .continuous))
    }
}

/// A circular brand-gradient chip carrying the mode's glyph, used as the hero icon wherever the
/// original relied on a plain `Label`.
private struct ModeIconChip: View {
    let icon: String
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(BrandGradient.diagonal, in: .circle)
    }
}

/// A green-gradient checkmark seal marking today's challenge as solved.
private struct SolvedSeal: View {
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.46, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.green.gradient, in: .circle)
    }
}

/// A Duolingo-style row of puzzle pieces, one per recent day: filled and tinted for a completed
/// day, outlined and dimmed for a day not yet played. Capacity adapts to the streak's length
/// (3 pieces minimum for visual rhythm even at streak 0, `maxCapacity` at most so it fits the
/// widget) — today sits on the trailing end, exactly like the checkmark row it's modeled on. Only
/// the completed run gets the brand-gradient capsule; days still pending sit outside it, bare.
/// When `showsWeekdayLabels` is set, the initials render as their own row above the pieces —
/// never inside the capsule stroke — so the capsule always wraps just the pieces.
private struct StreakPieceRow: View {
    let date: Date
    let streak: Int
    let isCompletedToday: Bool
    let accent: Color
    var maxCapacity: Int = 7
    var pieceSize: CGFloat = 18
    var spacing: CGFloat = 6
    var showsWeekdayLabels: Bool = true
    var alignment: Alignment = .center

    private var capacity: Int {
        min(max(streak + (isCompletedToday ? 0 : 1), 3), maxCapacity)
    }

    /// "Days ago" (0 = today) that fall within the still-alive streak.
    private var filledDaysAgo: Set<Int> {
        guard streak > 0 else { return [] }
        let start = isCompletedToday ? 0 : 1
        return Set(start..<(start + streak))
    }

    /// Oldest to newest (today trailing), split into the completed run and the still-pending tail.
    private var filledSlots: [Int] {
        slots.filter { filledDaysAgo.contains($0) }
    }
    private var pendingSlots: [Int] {
        slots.filter { !filledDaysAgo.contains($0) }
    }
    private var slots: [Int] {
        Array((0..<capacity).reversed())
    }

    var body: some View {
        VStack(spacing: 4) {
            if showsWeekdayLabels {
                weekdayLabelRow
            }
            pieceRow
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    /// A standalone row of weekday initials, mirroring the piece row's filled/pending grouping
    /// (including the capsule's horizontal padding) so each letter lines up with its piece below —
    /// without being wrapped by the capsule stroke itself.
    private var weekdayLabelRow: some View {
        HStack(spacing: spacing) {
            if !filledSlots.isEmpty {
                HStack(spacing: spacing) {
                    ForEach(filledSlots, id: \.self) { daysAgo in
                        weekdayLabel(daysAgo: daysAgo)
                    }
                }
                .padding(.horizontal, 8)
            }

            ForEach(pendingSlots, id: \.self) { daysAgo in
                weekdayLabel(daysAgo: daysAgo)
            }
        }
    }

    private var pieceRow: some View {
        HStack(spacing: spacing) {
            if !filledSlots.isEmpty {
                HStack(spacing: spacing) {
                    ForEach(filledSlots, id: \.self) { daysAgo in
                        piece(daysAgo: daysAgo, filled: true)
                    }
                }
                .padding(8)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(BrandGradient.diagonal, lineWidth: 2)
                }
            }

            ForEach(pendingSlots, id: \.self) { daysAgo in
                piece(daysAgo: daysAgo, filled: false)
            }
        }
    }

    private func piece(daysAgo: Int, filled: Bool) -> StreakPiece {
        StreakPiece(filled: filled, accent: accent, size: pieceSize)
    }

    private func weekdayLabel(daysAgo: Int) -> some View {
        Text(weekdayLetter(daysAgo: daysAgo))
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(.secondary)
            .frame(width: pieceSize)
    }

    private func weekdayLetter(daysAgo: Int) -> String {
        guard let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: date) else { return "" }
        return day.formatted(.dateTime.weekday(.narrow))
    }
}

/// One slot in `StreakPieceRow`: a puzzle-piece glyph that's either brand-tinted (done) or dimmed
/// and outlined (not yet).
private struct StreakPiece: View {
    let filled: Bool
    let accent: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: filled ? "puzzlepiece.fill" : "puzzlepiece")
            .font(.system(size: size))
            .foregroundStyle(filled ? accent : Color.white.opacity(0.18))
            .rotationEffect(.degrees(-45))
            .frame(width: size)
    }
}

/// A torn-calendar-page date chip — month/day/weekday stacked on a brand-gradient card — used in
/// place of the original's plain `Text(date, format:)` line.
private struct CalendarPageChip: View {
    let date: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(date, format: .dateTime.month(.abbreviated))
                .font(.system(size: 10, weight: .heavy))
                .kerning(0.8)
                .textCase(.uppercase)
            Text(date, format: .dateTime.day())
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text(date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 9, weight: .semibold))
                .opacity(0.85)
                .textCase(.uppercase)
        }
        .foregroundStyle(.white)
        .frame(width: 58)
        .padding(.vertical, 7)
        .background(
            LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom),
            in: .rect(cornerRadius: 14)
        )
    }
}

/// A solid gradient "Play" pill replacing the original's plain accent-colored `Label`.
private struct PlayCTAButton: View {
    var body: some View {
        Label("Play", systemImage: "play.fill")
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(BrandGradient.diagonal, in: .capsule)
    }
}

/// The alt widgets' background: a diagonal near-black gradient, a warm corner glow, and a large
/// faded, rotated brand mark watermark for texture the flat original lacks. `markOffsetX` lets
/// each family nudge the watermark into its own empty space — e.g. the medium layout's gap
/// between the mode text and the Play CTA.
private struct DailyAltBackground: View {
    var markOffsetX: CGFloat = 40

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.05), Color(white: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.orange.opacity(0.35), .clear],
                center: .bottomTrailing,
                startRadius: 4,
                endRadius: 160
            )
            BrandPuzzleMark(size: 130)
                .opacity(0.07)
                .rotationEffect(.degrees(18))
                .offset(x: markOffsetX, y: -40)
        }
    }
}

#Preview("Small Alt", as: .systemSmall) {
    DailyChallengeWidgetAlt()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide)
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 4, mode: .slide)
}

#Preview("Medium Alt", as: .systemMedium) {
    DailyChallengeWidgetAlt()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 50, bestStreak: 12, gridSize: 5, mode: .swap)
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 60, bestStreak: 12, gridSize: 5, mode: .swap)
}
