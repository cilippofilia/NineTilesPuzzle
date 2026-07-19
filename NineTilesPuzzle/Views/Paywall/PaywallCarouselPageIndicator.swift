//
//  PaywallCarouselPageIndicator.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// The Apple TV–style page indicator for `PaywallBenefitCarousel`: a row of dots where the
/// active page grows into a capsule that fills left-to-right as a countdown to the next
/// auto-advance. Driven by a plain integer `activeIndex` (rather than a slide's string id) so
/// it settles cleanly on each page instead of flickering as the scroll crosses slide bounds.
struct PaywallCarouselPageIndicator: View {
    /// Number of distinct pages — the dots track real benefits, not the looped slide copies.
    let count: Int
    /// The currently centered page, already reduced into `0..<count`.
    let activeIndex: Int
    /// How far the active page is through its dwell time, `0...1`. Drives the fill width.
    let progress: Double

    private let dotSize: CGFloat = 6
    private let activeWidth: CGFloat = 22
    private let spacing: CGFloat = 6

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                let isActive = index == activeIndex
                let width = isActive ? activeWidth : dotSize

                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: width, height: dotSize)
                    // Always present so the fill grows/shrinks with width instead of popping
                    // in and out as the active page changes.
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: isActive ? activeWidth * progress : 0, height: dotSize)
                    }
            }
        }
        .animation(.snappy(duration: 0.32), value: activeIndex)
    }
}

#Preview {
    VStack(spacing: 24) {
        PaywallCarouselPageIndicator(count: 4, activeIndex: 0, progress: 0.3)
        PaywallCarouselPageIndicator(count: 4, activeIndex: 2, progress: 0.7)
    }
    .padding()
    .background(.black)
}
