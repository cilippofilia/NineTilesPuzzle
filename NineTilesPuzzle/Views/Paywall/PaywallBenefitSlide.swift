//
//  PaywallBenefitSlide.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// The centered, full-width content of one page in `PaywallBenefitCarousel` — a large icon
/// badge over a bold lead-in phrase and its supporting sentence.
struct PaywallBenefitSlide: View {
    let benefit: PaywallBenefit

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: benefit.icon)
                    .font(.system(size: 18))
                    .frame(width: 33, height: 33)
                    .background(benefit.tint, in: .circle)

                Text(benefit.lead)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Text(benefit.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PaywallBenefitSlide(benefit: PaywallBenefit.all[0])
        .padding()
}
