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
            if !entry.isPremiumUnlocked {
                DailyUpgradeView()
            } else {
                switch family {
                case .systemMedium:
                    DailyMediumView(entry: entry)
                default:
                    DailySmallView(entry: entry)
                }
            }
        }
        .widgetURL(entry.isPremiumUnlocked ? DeepLink.daily.url : DeepLink.paywall.url)
    }
}

/// Shown instead of today's puzzle state when the player hasn't unlocked premium — Home
/// Screen widgets are an "Always Connected" system-integration upsell (`PremiumFeature.widgets`),
/// not a preview of the Daily Challenge itself. Tapping deep-links straight to the paywall.
struct DailyUpgradeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DailyHeaderLabel()

            Spacer()

            Label("Upgrade to VIP", systemImage: "lock.fill")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Resume games and track your streak from the Home Screen.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DailyWidgetMetrics.padding)
        .containerBackground(for: .widget) {
            DailyWidgetBackground(imageData: nil)
        }
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
        VStack(alignment: .leading) {
            HStack {
                CalendarPageChip(
                    date: entry.date,
                    chargeFraction: chargeFraction
                )

                VStack(alignment: .leading) {
                    DailyHeaderLabel()

                    HStack {
                        ModeIconChip(icon: entry.mode.icon, size: 26)

                        Text(entry.mode.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("\(entry.gridSize) × \(entry.gridSize) grid")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Group {
                            if entry.isCompletedToday {
                                SolvedSeal(size: 34)
                            } else {
                                PlayCTAButton()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline) {
                StreakPieceRow(
                    date: entry.date, streak: entry.streak, isCompletedToday: entry.isCompletedToday,
                    accent: accent, pieceSize: 18, spacing: 16, showsWeekdayLabels: true,
                    alignment: .leading
                )

                if entry.streak > 0 {
                    DailyStreakBadge(
                        icon: "flame.fill",
                        count: entry.streak,
                        accent: accent
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DailyWidgetMetrics.padding)
        .containerBackground(for: .widget) { DailyWidgetBackground(markOffsetX: 75, imageData: entry.imageData) }
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
        .font(.system(size: 18, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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

/// A Duolingo-style row of puzzle pieces, one per day of the current calendar week, Monday
/// through Sunday: filled and tinted for a day inside the still-alive streak, outlined and
/// dimmed for a day missed or still ahead. Unlike a rolling window, the week is fixed — so a
/// short streak started mid-week leaves the earlier days visibly unfilled, and days after today
/// sit there as the week ahead. Only the completed run gets the brand-gradient capsule; days
/// outside it sit bare, whether they come before or after the run. When `showsWeekdayLabels` is
/// set, the initials render as their own row above the pieces — never inside the capsule stroke —
/// so the capsule always wraps just the pieces.
private struct StreakPieceRow: View {
    let date: Date
    let streak: Int
    let isCompletedToday: Bool
    let accent: Color
    var pieceSize: CGFloat = 18
    var spacing: CGFloat = 6
    var showsWeekdayLabels: Bool = true
    var alignment: Alignment = .center

    private var runs: [[WeeklyStreakLayout.Day]] {
        WeeklyStreakLayout(referenceDate: date, streak: streak, isCompletedToday: isCompletedToday).runs
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

    /// A standalone row of weekday initials, applying the same per-run padding and inter-run gap
    /// as the piece row unconditionally — filled or not — so every letter lines up with its piece
    /// below no matter which days are filled.
    private var weekdayLabelRow: some View {
        HStack(spacing: Self.runGap) {
            ForEach(runs, id: \.self) { run in
                HStack(spacing: spacing) {
                    ForEach(run, id: \.self) { day in weekdayLabel(for: day) }
                }
                .padding(.horizontal, Self.runHorizontalPadding)
            }
        }
    }

    /// Every run gets identical padding and a capsule overlay regardless of fill state — only
    /// the stroke's opacity differs — so the row's proportions never shift based on the streak.
    private var pieceRow: some View {
        HStack(spacing: Self.runGap) {
            ForEach(runs, id: \.self) { run in
                let isFilled = run.first?.isFilled == true
                HStack(spacing: spacing) {
                    ForEach(run, id: \.self) { day in piece(filled: isFilled) }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, Self.runHorizontalPadding)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(BrandGradient.diagonal, lineWidth: 2)
                        .opacity(isFilled ? 1 : 0)
                }
            }
        }
    }

    /// Clearance between the capsule stroke and the pieces it wraps — shared by both rows so the
    /// letters stay aligned with their pieces. Kept generous (unlike `runGap`) since this is
    /// what keeps the stroke from crowding the first/last piece it wraps.
    private static let runHorizontalPadding: CGFloat = 8
    /// Gap between separate runs (a capsule and the plain pieces beside it) — deliberately
    /// tighter than the piece-to-piece spacing within a run, so pending days don't drift far
    /// from the streak they're adjacent to.
    private static let runGap: CGFloat = 6

    private func piece(filled: Bool) -> StreakPiece {
        StreakPiece(filled: filled, accent: accent, size: pieceSize)
    }

    private func weekdayLabel(for day: WeeklyStreakLayout.Day) -> some View {
        Text(day.date.formatted(.dateTime.weekday(.narrow)))
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(.secondary)
            .frame(width: pieceSize)
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
        .frame(width: 60)
        .padding(.vertical, 8)
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
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: true
    )
    DailyChallengeEntry(
        date: .now, isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: true
    )
}

/// Long-running streaks push `DailyStreakFlame` to its size cap — this catches clipping that a
/// low mock streak (like the "Small" preview above) never would.
#Preview("Small — High Streak", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(date: .now, isCompletedToday: true, streak: 20, bestStreak: 20, gridSize: 4, mode: .slide, imageData: nil, isPremiumUnlocked: true)
}

#Preview("Medium", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 50, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true
    )
    DailyChallengeEntry(
        date: .now, isCompletedToday: true, streak: 60, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true
    )
}

/// The streak row's fixed Monday–Sunday week at a few notable lengths: no streak, a short one
/// starting mid-week, one nearing the end of the week, and a full week — cycle the canvas's
/// timeline scrubber to see all four.
#Preview("Medium — Streak Lengths", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    for streak in [0, 3, 5, 7] {
        DailyChallengeEntry(
            date: .now, isCompletedToday: true, streak: streak, bestStreak: 12, gridSize: 5, mode: .swap,
            imageData: nil, isPremiumUnlocked: true
        )
    }
}

#Preview("Locked", as: .systemSmall) {
    DailyChallengeWidget()
} timeline: {
    DailyChallengeEntry(
        date: .now, isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 4, mode: .slide,
        imageData: nil, isPremiumUnlocked: false
    )
}

/// The date badge's battery-style charge at each step through the day — cycle the canvas's
/// timeline scrubber to see all six. The first five are a solved-free day (100% → 20% in fifths);
/// the last shows a solved day pinned full at the same late hour, for contrast.
#Preview("Charge Levels", as: .systemMedium) {
    DailyChallengeWidget()
} timeline: {
    let calendar = Calendar.current
    let today = Date.now
    for hour in [1, 6, 11, 16, 21] {
        DailyChallengeEntry(
            date: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!,
            isCompletedToday: false, streak: 5, bestStreak: 12, gridSize: 5, mode: .swap,
            imageData: nil, isPremiumUnlocked: true
        )
    }
    DailyChallengeEntry(
        date: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today)!,
        isCompletedToday: true, streak: 6, bestStreak: 12, gridSize: 5, mode: .swap,
        imageData: nil, isPremiumUnlocked: true
    )
}
