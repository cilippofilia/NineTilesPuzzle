//
//  DailyStreakBadgeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import SwiftUI

/// Small golden counter shown on the last completed day of an ongoing
/// daily-challenge streak, echoing the calendar cell's golden frame.
struct DailyStreakBadgeView: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(.caption2)
            .bold()
            .monospacedDigit()
            .foregroundStyle(.black)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.yellow.gradient, in: .rect(cornerRadius: 6))
    }
}

#Preview {
    HStack {
        DailyStreakBadgeView(count: 2)
        DailyStreakBadgeView(count: 114)
    }
    .padding()
}
