//
//  DailyStreakFlame.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// A flame silhouette rising from the bottom edge, standing in for the small widget's old piece
/// row: an unlit grey ember while today is still pending, blooming into a glowing brand-gradient
/// blaze once it's solved. It grows with the streak itself — a small ember at the start of a run,
/// a fuller flame the longer it goes — so the shape carries meaning, not just decoration. The
/// streak count sits directly on top, the whole thing reading as one gauge.
struct DailyStreakFlame: View {
    let streak: Int
    let isCompletedToday: Bool
    /// True when today was frozen by an image-provider outage rather than completed — swaps
    /// the flame for a snowflake and its brand gradient for blue, "lit" the same as a solved day.
    var isFrozen: Bool = false

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

    private var isLit: Bool { isCompletedToday || isFrozen }
    private var glyphName: String { isFrozen ? "snowflake" : "flame.fill" }
    private var glowColor: Color { isFrozen ? .blue.mix(with: .white, by: 0.25) : .orange }
    /// No white in this gradient (unlike the flame's warm diagonal) — the streak numeral sits
    /// in white text directly on top of the glyph, and a white snowflake tip behind white digits
    /// was reading as barely-there. Deep blue keeps the glyph legible as "lit" while never
    /// competing with the text.
    private var glyphGradient: LinearGradient {
        isFrozen
            ? LinearGradient(colors: [.cyan, .blue, .indigo], startPoint: .top, endPoint: .bottom)
            : BrandGradient.diagonal
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                if isLit {
                    Image(systemName: glyphName)
                        .font(.system(size: flameSize * 1.15))
                        .foregroundStyle(glowColor)
                        .blur(radius: 20)
                        .opacity(0.4)
                }

                Image(systemName: glyphName)
                    .font(.system(size: flameSize))
                    .foregroundStyle(glyphGradient)
                    .saturation(isLit ? 1 : 0)
                    .opacity(isLit ? 1 : 0.25)
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
                // Frozen's glyph reads brighter behind the numeral than the flame does, so its
                // shadow needs to work harder to keep the white digits legible on top of it.
                .shadow(color: .black.opacity(isFrozen ? 0.7 : 0.4), radius: isFrozen ? 5 : 3, y: 1)
                // Fixed, not derived from visibleHeight: the streak number/label must keep the
                // same safe clearance from the true bottom edge no matter how big the flame gets.
                .padding(.bottom, 14)
            } else {
                // Same nudge copy as the medium widget's fallback, laid out over the unlit
                // ember rather than in the content flow — this card has no other row to hold it.
                Text(DailyWidgetMetrics.noStreakPrompt)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 14)
            }
        }
        // Fill the whole background proposal and pin to its bottom — without the max-height
        // fill the stack sizes to its content and the container centers it vertically, which
        // is what left the flame floating above the widget's bottom edge.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
