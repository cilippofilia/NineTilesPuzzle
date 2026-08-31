//
//  DailyHeroRow.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// The small card's middle row — a 30pt icon chip beside a hero title and small-caps-style
/// subtitle. Both the "solved" and "play today" states render through this one struct with the
/// same fonts and metrics, so swapping states never shifts the row's position, only its content.
struct DailyHeroRow<Icon: View>: View {
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
