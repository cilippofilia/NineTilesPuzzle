//
//  PaywallBenefitRow.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import SwiftUI

/// One line in `PaywallView`'s fixed benefit list — a bold lead-in phrase followed by the
/// rest of the sentence, e.g. "**Break the Rules:** Access all 7 game modes…".
struct PaywallBenefitRow: View {
    let lead: String
    let detail: String

    var body: some View {
        Label {
            Text("\(Text(lead).bold()): \(detail)")
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    PaywallBenefitRow(
        lead: "Break the Rules",
        detail: "Access all 7 game modes, including Chaos and Haze."
    )
    .padding()
}
