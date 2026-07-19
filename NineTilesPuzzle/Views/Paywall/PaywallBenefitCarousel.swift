//
//  PaywallBenefitCarousel.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// A self-advancing, infinitely looping carousel of `PaywallBenefit` slides — modeled on the
/// Apple TV featured shelf: "what you get" plays as a slow rotation of pitches you can also
/// swipe through, and it never hits an edge. The benefits are laid out many times over into a
/// long buffer with the scroll parked in the middle, so paging forward or back always lands on
/// a real neighbour; the rare drift toward either end is silently recentered. An Apple
/// TV–style dot indicator tracks the current page and fills as a countdown to the next slide.
struct PaywallBenefitCarousel: View {
    let benefits: [PaywallBenefit]

    /// How long each slide dwells before the carousel advances on its own.
    private let advanceInterval: Double = 4

    /// One physical slide in the looped buffer: the same benefit shows up `repetitions` times,
    /// each with a distinct id so `scrollPosition` can tell the copies apart.
    private struct LoopSlide: Identifiable {
        let id: Int
        let benefit: PaywallBenefit
    }

    /// Odd so the middle repetition begins exactly on a benefit boundary.
    private static let repetitions = 201

    private let slides: [LoopSlide]
    /// Index in `slides` where the centered repetition starts — our neutral home position.
    private let middle: Int

    @State private var scrollID: Int?
    @State private var progress: Double = 0
    @State private var advanceTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(benefits: [PaywallBenefit]) {
        self.benefits = benefits
        self.slides = (0 ..< benefits.count * Self.repetitions).map { index in
            LoopSlide(id: index, benefit: benefits[index % benefits.count])
        }
        self.middle = benefits.count * (Self.repetitions / 2)
        _scrollID = State(initialValue: benefits.count * (Self.repetitions / 2))
    }

    /// The centered page reduced to `0..<benefits.count`, for the dot indicator.
    private var activeIndex: Int {
        guard let scrollID, !benefits.isEmpty else { return 0 }
        return ((scrollID % benefits.count) + benefits.count) % benefits.count
    }

    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(slides) { slide in
                        PaywallBenefitSlide(benefit: slide.benefit)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollID)
            .scrollIndicators(.hidden)

            PaywallCarouselPageIndicator(
                count: benefits.count,
                activeIndex: activeIndex,
                progress: reduceMotion ? 0 : progress
            )
            .padding(.vertical, 8)
        }
        .onChange(of: scrollID) { _, _ in recenterIfNeeded() }
        .onChange(of: activeIndex) { _, _ in
            restartProgress()
            scheduleAdvance()
        }
        .task {
            restartProgress()
            scheduleAdvance()
        }
        .onDisappear { advanceTask?.cancel() }
    }

    /// Restart the fill countdown for the current slide. On each page change the fill snaps to
    /// empty and then eases to full over the dwell time; static when motion is reduced.
    private func restartProgress() {
        progress = 0
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: advanceInterval)) { progress = 1 }
    }

    /// Queue the next auto-advance, cancelling any pending one so a manual swipe resets the
    /// countdown instead of racing an older timer. No-op under reduced motion.
    private func scheduleAdvance() {
        advanceTask?.cancel()
        guard !reduceMotion else { return }
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(advanceInterval))
            guard !Task.isCancelled, let scrollID else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                self.scrollID = scrollID + 1
            }
        }
    }

    /// Keep the scroll parked near the middle of the buffer. If paging has drifted within one
    /// full cycle of either end, jump — without animation — to the identical page back in the
    /// centered repetition so there's always runway in both directions and nothing to see.
    private func recenterIfNeeded() {
        guard let scrollID else { return }
        let lowerBound = benefits.count
        let upperBound = slides.count - benefits.count
        guard scrollID < lowerBound || scrollID >= upperBound else { return }
        self.scrollID = middle + activeIndex
    }
}

#Preview {
    PaywallBenefitCarousel(benefits: PaywallBenefit.all)
        .frame(height: 160)
        .padding()
        .background(.black)
}
