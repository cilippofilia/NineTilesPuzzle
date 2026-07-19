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

    /// Shared with `PaywallCarouselPageIndicator` so the dot's morph finishes in step with the
    /// slide's glide instead of settling early on a faster timing of its own.
    private static let transitionDuration: Double = 0.55

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
    /// The page shown to the dot indicator — only ever written once the scroll view is at rest.
    /// `scrollID` itself emits transient and momentarily-nil values while a swipe or the
    /// animated auto-advance is in flight; reading those live into the indicator is what made
    /// it flicker.
    @State private var displayedIndex: Int = 0
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

    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(slides) { slide in
                        PaywallBenefitSlide(benefit: slide.benefit)
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.4)
                                    .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.92)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollID)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, newPhase in
                guard newPhase == .idle else { return }
                settleOnCurrentPage()
            }

            PaywallCarouselPageIndicator(
                count: benefits.count,
                activeIndex: displayedIndex,
                progress: reduceMotion ? 0 : progress,
                transitionDuration: Self.transitionDuration
            )
            .padding(.vertical, 8)
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
    ///
    /// Drives the indicator directly from here rather than waiting for `onScrollPhaseChange` to
    /// report `.idle`: whether that phase callback fires for a binding-driven (as opposed to a
    /// user-gesture-driven) scroll is unconfirmed, and if it didn't, the whole loop — advance,
    /// dot, reschedule — would silently stall after one slide.
    private func scheduleAdvance() {
        advanceTask?.cancel()
        guard !reduceMotion else { return }
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(advanceInterval))
            guard !Task.isCancelled, let scrollID else { return }
            let nextScrollID = scrollID + 1
            withAnimation(.smooth(duration: Self.transitionDuration)) {
                self.scrollID = nextScrollID
            }
            commit(scrollID: nextScrollID)
        }
    }

    /// Reconciles the indicator and the auto-advance countdown with reality now that the scroll
    /// view has actually come to rest — the one moment `scrollID` can be trusted. Ignoring it at
    /// every other phase (tracking, decelerating, animating) is what stops the dots from
    /// flickering to the wrong page or resetting their fill mid-swipe.
    private func settleOnCurrentPage() {
        guard let scrollID else { return }
        commit(scrollID: scrollID)
    }

    /// Shared by the manual-swipe settle path and the programmatic auto-advance path: recenters
    /// the buffer, then updates the indicator and restarts the countdown only if the page
    /// actually changed. The no-op guard makes it safe to call from both paths for the same
    /// advance without double-restarting the countdown.
    private func commit(scrollID: Int) {
        guard !benefits.isEmpty else { return }
        let normalized = ((scrollID % benefits.count) + benefits.count) % benefits.count
        recenter(from: scrollID, normalized: normalized)
        guard normalized != displayedIndex else { return }
        displayedIndex = normalized
        restartProgress()
        scheduleAdvance()
    }

    /// Keep the scroll parked near the middle of the buffer. If paging has drifted within one
    /// full cycle of either end, jump — without animation — to the identical page back in the
    /// centered repetition so there's always runway in both directions and nothing to see.
    private func recenter(from scrollID: Int, normalized: Int) {
        let lowerBound = benefits.count
        let upperBound = slides.count - benefits.count
        guard scrollID < lowerBound || scrollID >= upperBound else { return }
        self.scrollID = middle + normalized
    }
}

#Preview {
    PaywallBenefitCarousel(benefits: PaywallBenefit.all)
        .frame(height: 160)
        .padding()
        .background(.black)
}
