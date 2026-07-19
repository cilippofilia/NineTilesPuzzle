//
//  DailyChallengeViews.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI
import WidgetKit

/// Family switch for the Daily Challenge widget: a glowing brand-gradient watermark, a
/// calendar-page date chip, and gradient hero numerals throughout. The whole widget is one
/// destination, so a single `widgetURL` covers every family.
struct DailyChallengeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyChallengeEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                DailyMediumView(entry: entry)
            default:
                DailySmallView(entry: entry)
            }
        }
        .widgetURL(DeepLink.daily.url)
    }
}

/// Small home-screen card: minimal wordmark header, a hero-sized grid readout (or solved seal),
/// and a big brand-gradient flame rising from the bottom edge marking the streak.
struct DailySmallView: View {
    let entry: DailyChallengeEntry

    var body: some View {
        VStack(alignment: .leading) {
            DailyHeaderLabel()

            if entry.isCompletedToday {
                DailyHeroRow(title: Text("Solved"), subtitle: "Come back tomorrow") {
                    SolvedSeal(size: 30)
                }
            } else {
                DailyHeroRow(
                    title: Text("\(entry.gridSize)×\(entry.gridSize)").foregroundStyle(BrandGradient.diagonal),
                    subtitle: entry.mode.title.uppercased()
                ) {
                    ModeIconChip(icon: entry.mode.icon, size: 30)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DailyWidgetMetrics.padding)
        .containerBackground(for: .widget) {
            ZStack {
                DailyWidgetBackground(showsWatermark: false, imageData: entry.imageData)
                DailyStreakFlame(streak: entry.streak, isCompletedToday: entry.isCompletedToday)
            }
        }
    }
}

/// Medium home-screen card: a torn-calendar-page date chip and mode identity up top, a gradient
/// "Play" pill (or solved seal) alongside them, and a full-width Duolingo-style puzzle-piece
/// streak row — with weekday initials — anchoring the bottom.
struct DailyMediumView: View {
    let entry: DailyChallengeEntry
    private let accent = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                CalendarPageChip(date: entry.date, chargeFraction: chargeFraction)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        DailyHeaderLabel()
                        Spacer(minLength: 0)
                        if entry.streak > 0 {
                            DailyStreakBadge(icon: "flame.fill", count: entry.streak, accent: accent)
                        }
                    }
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
            }

            StreakPieceRow(
                date: entry.date, streak: entry.streak, isCompletedToday: entry.isCompletedToday,
                accent: accent, maxCapacity: 9, pieceSize: 18, spacing: 16, showsWeekdayLabels: true,
                alignment: .leading
            )
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DailyWidgetMetrics.padding)
        .containerBackground(for: .widget) { DailyWidgetBackground(markOffsetX: 70, imageData: entry.imageData) }
    }

    /// The date badge's battery-style charge: pinned full once today is solved, otherwise
    /// stepping down in fifths as the day elapses — the last fifth stays lit as a "time's
    /// running out" cue rather than draining to nothing.
    private var chargeFraction: Double {
        guard !entry.isCompletedToday else { return 1 }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: entry.date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 1 }
        let dayLength = dayEnd.timeIntervalSince(dayStart)
        guard dayLength > 0 else { return 1 }
        let elapsedFraction = entry.date.timeIntervalSince(dayStart) / dayLength
        let consumedChunks = min(floor(elapsedFraction * 5), 4)
        return 1 - consumedChunks * 0.2
    }
}

/// Layout constants shared by both families so their edges align when placed side by side.
enum DailyWidgetMetrics {
    /// One padding for every edge of both the small and medium cards — the system content
    /// margins are disabled on the widget configuration in favor of this.
    static let padding: CGFloat = 14
}

/// Shared red→yellow brand gradient used across the widget's hero elements.
private enum BrandGradient {
    static let diagonal = LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
}

/// The small card's middle row — a 30pt icon chip beside a hero title and small-caps-style
/// subtitle. Both the "solved" and "play today" states render through this one struct with the
/// same fonts and metrics, so swapping states never shifts the row's position, only its content.
private struct DailyHeroRow<Icon: View>: View {
    let title: Text
    let subtitle: String
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 8) {
            icon
            VStack(alignment: .leading) {
                title
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// A minimal wordmark header — brand glyph plus tracked-out "DAILY PUZZLE".
private struct DailyHeaderLabel: View {
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

/// A flame silhouette rising from the bottom edge, standing in for the small widget's old piece
/// row: an unlit grey ember while today is still pending, blooming into a glowing brand-gradient
/// blaze once it's solved. It grows with the streak itself — a small ember at the start of a run,
/// a fuller flame the longer it goes — so the shape carries meaning, not just decoration. The
/// streak count sits directly on top, the whole thing reading as one gauge.
private struct DailyStreakFlame: View {
    let streak: Int
    let isCompletedToday: Bool

    /// Capped small enough, and cropped hard enough, that only a low ember stays visible above
    /// the bottom edge — clear of the header/mode row even on the smallest small-widget size
    /// class. Long streaks (20+ days) hit the cap; verified against the "Small — High Streak"
    /// preview below, since the default preview timeline never climbs past a streak of 6.
    private var flameSize: CGFloat {
        min(90 + CGFloat(streak) * 2, 130)
    }

    /// The flame glyph is drawn much taller than what's kept on screen; clipping to a fixed,
    /// top-anchored height (rather than nudging the whole shape down with an offset and hoping
    /// it lines up with the container's edge) guarantees the crop always shows the glyph's
    /// tapered tip flush against the true bottom — no dead gap, no guessing.
    private var visibleHeight: CGFloat {
        flameSize * 0.66
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                if isCompletedToday {
                    Image(systemName: "flame.fill")
                        .font(.system(size: flameSize * 1.15))
                        .foregroundStyle(Color.orange)
                        .blur(radius: 20)
                        .opacity(0.4)
                }

                Image(systemName: "flame.fill")
                    .font(.system(size: flameSize))
                    .foregroundStyle(BrandGradient.diagonal)
                    .saturation(isCompletedToday ? 1 : 0)
                    .opacity(isCompletedToday ? 1 : 0.25)
                    .frame(height: visibleHeight, alignment: .top)
                    .clipped()
            }

            if streak > 0 {
                VStack(spacing: 0) {
                    Text("\(streak)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("DAY STREAK")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                // Fixed, not derived from visibleHeight: the streak number/label must keep the
                // same safe clearance from the true bottom edge no matter how big the flame gets.
                .padding(.bottom, 14)
            }
        }
        // Fill the whole background proposal and pin to its bottom — without the max-height
        // fill the stack sizes to its content and the container centers it vertically, which
        // is what left the flame floating above the widget's bottom edge.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

/// A flame- or trophy-and-count capsule marking the streak's current/best length — echoes the
/// same badge pattern used by the in-game Live Activity, styled to match this widget's own
/// `.ultraThinMaterial` header chip rather than the Dynamic Island's translucent one.
private struct DailyStreakBadge: View {
    let icon: String
    let count: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(accent)
            Text("\(count)")
                .foregroundStyle(.white)
        }
        .font(.system(size: 16, weight: .heavy, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: .capsule)
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

/// A torn-calendar-page date chip — month/day/weekday stacked on a brand-gradient card.
/// `chargeFraction` (1 = full) drains the gradient from the top down like a battery, leaving a
/// dimmed ghost of the same gradient behind — a passive cue that the day (and the chance to
/// play) is running out.
private struct CalendarPageChip: View {
    let date: Date
    var chargeFraction: Double = 1

    private var dateGradient: LinearGradient {
        LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
    }

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
        .background {
            let drainedFraction = 1 - chargeFraction
            ZStack {
                dateGradient.opacity(0.3)
                dateGradient
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: drainedFraction),
                                .init(color: .white, location: drainedFraction)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
        .clipShape(.rect(cornerRadius: 14))
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

/// The widget's background: a diagonal near-black gradient, a warm corner glow, and a large
/// rotated puzzle-piece watermark for texture. `markOffsetX` lets each family nudge the
/// watermark into its own empty space — e.g. the medium layout's gap between the mode text and
/// the Play CTA. Once today's seeded photo has loaded, the watermark shows that photo masked
/// into the piece's silhouette instead of the plain brand gradient.
private struct DailyWidgetBackground: View {
    var markOffsetX: CGFloat = 40
    var showsWatermark: Bool = true
    var imageData: Data?

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
            if showsWatermark {
                watermark
                    .rotationEffect(.degrees(18))
                    .offset(x: markOffsetX, y: -40)
            }
        }
    }

    @ViewBuilder
    private var watermark: some View {
        if let imageData, let photo = UIImage(data: imageData) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 130)
                .mask(BrandPuzzleMark(size: 130))
                .opacity(0.45)
        } else {
            BrandPuzzleMark(size: 130)
                .opacity(0.07)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide, imageData: nil)
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 4, mode: .slide, imageData: nil)
}

/// Long-running streaks push `DailyStreakFlame` to its size cap — this catches clipping that a
/// low mock streak (like the "Small" preview above) never would.
#Preview("Small — High Streak", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 20, bestStreak: 20, gridSize: 4, mode: .slide, imageData: nil)
}

#Preview("Medium", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: false, streak: 50, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 60, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
}

/// The date badge's battery-style charge at each step through the day — cycle the canvas's
/// timeline scrubber to see all six. The first five are a solved-free day (100% → 20% in fifths);
/// the last shows a solved day pinned full at the same late hour, for contrast.
#Preview("Charge Levels", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    let calendar = Calendar.current
    let today = Date.now
    DailyChallengeEntry(date: calendar.date(bySettingHour: 1, minute: 0, second: 0, of: today)!, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
    DailyChallengeEntry(date: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: today)!, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
    DailyChallengeEntry(date: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: today)!, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
    DailyChallengeEntry(date: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today)!, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
    DailyChallengeEntry(date: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today)!, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
    DailyChallengeEntry(date: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today)!, isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 5, mode: .swap, imageData: nil)
}
