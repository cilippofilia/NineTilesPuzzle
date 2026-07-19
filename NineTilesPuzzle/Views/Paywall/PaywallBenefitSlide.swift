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
        VStack(spacing: 6) {
            HStack {
                Image(systemName: benefit.icon)
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .background(benefit.tint, in: .circle)

                Text(benefit.lead)
                    .font(.system(size: 18))
                    .bold()
                    .foregroundStyle(.primary)
            }

            Text(benefit.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                
        }
        .padding([.horizontal, .top])
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

#Preview {
    PaywallBenefitSlide(benefit: PaywallBenefit.all[0])
}
