//
//  PaywallBenefitRow.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// One line in `PaywallView`'s fixed benefit list — a colored icon badge distinct per
/// benefit (rather than a repeated checkmark) followed by a bold lead-in phrase and the
/// rest of the sentence, e.g. "**Break the Rules:** Access all 7 game modes…".
struct PaywallBenefitRow: View {
    let icon: String
    let tint: Color
    let lead: String
    let detail: String

    var body: some View {
        Label {
            Text("\(Text(lead).bold()): \(detail)")
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon)
                .font(.footnote.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint.gradient, in: .circle)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        PaywallBenefitRow(
            icon: "gamecontroller.fill",
            tint: .purple,
            lead: "Break the Rules",
            detail: "Access all 7 game modes, including Chaos and Haze."
        )
        PaywallBenefitRow(
            icon: "camera.fill",
            tint: .pink,
            lead: "Make it Personal",
            detail: "Slice your own photos or snap one instantly with Quick Snap."
        )
        PaywallBenefitRow(
            icon: "trophy.fill",
            tint: .orange,
            lead: "Claim Your Seat",
            detail: "Unlock the Wall of Fame and all 39 achievements."
        )
        PaywallBenefitRow(
            icon: "widget.small.badge.plus",
            tint: .blue,
            lead: "Always Connected",
            detail: "Live Activities, Dynamic Island, and Home Screen widgets."
        )
    }
    .padding()
}
