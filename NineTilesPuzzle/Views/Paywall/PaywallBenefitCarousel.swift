//
//  PaywallBenefitCarousel.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// A swipeable, one-page-at-a-time carousel of `PaywallBenefit` slides — replaces a fixed
/// list so "what you get" reads as a sequence of pitches rather than a wall of text, with a
/// dot indicator tracking the current page.
struct PaywallBenefitCarousel: View {
    let benefits: [PaywallBenefit]

    @State private var currentID: String?

    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(benefits) { benefit in
                        PaywallBenefitSlide(benefit: benefit)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)

            HStack(spacing: 6) {
                ForEach(benefits) { benefit in
                    Capsule()
                        .fill(benefit.id == currentID ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: benefit.id == currentID ? 16 : 6, height: 6)
                }
            }
            .animation(.snappy, value: currentID)
            .padding(.vertical, 8)
        }
        .task {
            if currentID == nil { currentID = benefits.first?.id }
        }
    }
}

#Preview {
    PaywallBenefitCarousel(benefits: PaywallBenefit.all)
        .padding()
        .background(.black)
}
