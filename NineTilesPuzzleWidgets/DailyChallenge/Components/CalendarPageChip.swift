//
//  CalendarPageChip.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// A torn-calendar-page date chip — month/day/weekday stacked on a brand-gradient card.
/// `chargeFraction` (1 = full) drains the gradient from the top down like a battery, leaving a
/// dimmed ghost of the same gradient behind — a passive cue that the day (and the chance to
/// play) is running out.
struct CalendarPageChip: View {
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
