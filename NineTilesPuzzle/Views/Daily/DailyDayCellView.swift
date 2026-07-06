//
//  DailyDayCellView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import SwiftUI

/// The completion status of a single day in the history calendar.
enum DailyDayState {
    /// The daily challenge was completed — show that day's puzzle image.
    case completed
    /// The day has passed without a completion.
    case missed
    /// The day hasn't arrived yet.
    case upcoming
}

/// One day cell in the daily-challenge history calendar. Completed days show
/// the day's seeded puzzle image inside a golden square frame; missed days
/// render as empty circles, and upcoming days as fainter empty squares.
/// The last day of an ongoing 2+ day streak carries a numbered streak badge.
struct DailyDayCellView: View {
    let date: Date
    let state: DailyDayState
    var streakCount: Int?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if state == .completed {
                    AsyncImage(url: DailyChallengeSeeder.imageURL(for: date, size: 256)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.clear.background(.quaternary)
                    }
                }
            }
            .background(backgroundStyle, in: cellShape)
            .clipShape(cellShape)
            .overlay {
                if state == .completed {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.yellow.gradient, lineWidth: 2)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let streakCount, state == .completed {
                    DailyStreakBadgeView(count: streakCount)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).month(.wide).day()))
            .accessibilityValue(accessibilityValue)
    }

    /// Missed days read as circles so past gaps are visually distinct from the
    /// squares used for completed days and days still to come.
    private var cellShape: AnyShape {
        state == .missed ? AnyShape(.circle) : AnyShape(.rect(cornerRadius: 12))
    }

    private var backgroundStyle: AnyShapeStyle {
        switch state {
        case .completed: AnyShapeStyle(.quaternary)
        case .missed: AnyShapeStyle(.quaternary)
        case .upcoming: AnyShapeStyle(.quaternary.opacity(0.4))
        }
    }

    private var accessibilityValue: Text {
        switch state {
        case .completed:
            if let streakCount {
                Text("Completed, \(streakCount) day streak")
            } else {
                Text("Completed")
            }
        case .missed: Text("Not completed")
        case .upcoming: Text("Upcoming")
        }
    }
}

#Preview {
    HStack {
        DailyDayCellView(date: .now, state: .completed)
        DailyDayCellView(date: .now, state: .completed, streakCount: 114)
        DailyDayCellView(date: .now, state: .missed)
        DailyDayCellView(date: .now, state: .upcoming)
    }
    .padding()
}
