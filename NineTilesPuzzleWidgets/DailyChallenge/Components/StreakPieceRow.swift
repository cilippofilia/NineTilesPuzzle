//
//  StreakPieceRow.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// A Duolingo-style row of puzzle pieces, one per day of the current calendar week, Monday
/// through Sunday: filled and tinted for a day inside the still-alive streak, outlined and
/// dimmed for a day missed or still ahead. Unlike a rolling window, the week is fixed — so a
/// short streak started mid-week leaves the earlier days visibly unfilled, and days after today
/// sit there as the week ahead. Only the completed run gets the brand-gradient capsule; days
/// outside it sit bare, whether they come before or after the run. When `showsWeekdayLabels` is
/// set, the initials render as their own row above the pieces — never inside the capsule stroke —
/// so the capsule always wraps just the pieces.
struct StreakPieceRow: View {
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
struct StreakPiece: View {
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
