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
    /// The image provider was unreachable that day; the streak was frozen rather than broken.
    case frozen
    /// The day has passed without a completion.
    case missed
    /// The day hasn't arrived yet.
    case upcoming
}

/// One day cell in the daily-challenge history calendar. Completed days show
/// the day's seeded puzzle image inside a golden square frame; frozen days (an
/// outage protected the streak instead of breaking it) show a snowflake inside
/// a light-blue-to-white frame; missed days render as empty circles, and
/// upcoming days as fainter empty squares. The last day of an ongoing 2+ day
/// streak carries a numbered streak badge.
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
                } else if state == .frozen {
                    Image(systemName: "snowflake")
                        .foregroundStyle(.blue)
                        .imageScale(.large)
                }
            }
            .background(backgroundStyle, in: cellShape)
            .clipShape(cellShape)
            .overlay {
                if state == .completed {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.yellow.gradient, lineWidth: 2)
                } else if state == .frozen {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(frozenGradient, lineWidth: 2)
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
    /// squares used for completed, frozen, and upcoming days.
    private var cellShape: AnyShape {
        state == .missed ? AnyShape(.circle) : AnyShape(.rect(cornerRadius: 12))
    }

    private var backgroundStyle: AnyShapeStyle {
        switch state {
        case .completed: AnyShapeStyle(.quaternary)
        case .frozen: AnyShapeStyle(frozenGradient.opacity(0.35))
        case .missed: AnyShapeStyle(.quaternary)
        case .upcoming: AnyShapeStyle(.quaternary.opacity(0.4))
        }
    }

    private var frozenGradient: LinearGradient {
        LinearGradient(colors: [.blue.opacity(0.6), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var accessibilityValue: Text {
        switch state {
        case .completed:
            if let streakCount {
                Text("Completed, \(streakCount) day streak")
            } else {
                Text("Completed")
            }
        case .frozen: Text("Streak frozen, image provider was unavailable")
        case .missed: Text("Not completed")
        case .upcoming: Text("Upcoming")
        }
    }
}

#Preview {
    HStack {
        DailyDayCellView(date: .now, state: .completed)
        DailyDayCellView(date: .now, state: .completed, streakCount: 114)
        DailyDayCellView(date: .now, state: .frozen)
        DailyDayCellView(date: .now, state: .missed)
        DailyDayCellView(date: .now, state: .upcoming)
    }
    .padding()
}
