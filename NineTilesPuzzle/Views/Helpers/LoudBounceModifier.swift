//
//  LoudBounceModifier.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import SwiftUI

/// Repeating iMessage Loud+Shake style animation. Scale pops with a low-damping spring
/// (natural overshoot), a brightness flash fires on impact, then a horizontal rattle follows.
struct LoudBounceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: Values(), repeating: true) { view, value in
                view
                    .scaleEffect(value.scale)
                    .brightness(value.brightness)
                    .offset(x: value.offsetX)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1.0, duration: 0.8)
                    SpringKeyframe(1.25, duration: 0.25, spring: Spring(response: 0.25, dampingRatio: 0.48))
                    SpringKeyframe(1.0, duration: 0.62, spring: Spring(response: 0.42, dampingRatio: 0.66))
                    LinearKeyframe(1.0, duration: 3.0)
                }
                // Brightness flash coincides with the peak of the scale pop
                KeyframeTrack(\.brightness) {
                    LinearKeyframe(0.0, duration: 0.8)
                    SpringKeyframe(0.12, duration: 0.18, spring: .snappy)
                    SpringKeyframe(0.0, duration: 0.65, spring: .smooth)
                    LinearKeyframe(0.0, duration: 3.0)
                }
                // Horizontal rattle kicks in just after the pop lands
                KeyframeTrack(\.offsetX) {
                    LinearKeyframe(0, duration: 1.05)
                    LinearKeyframe(-7, duration: 0.09)
                    LinearKeyframe(7, duration: 0.09)
                    LinearKeyframe(-5, duration: 0.09)
                    LinearKeyframe(5, duration: 0.09)
                    LinearKeyframe(-3, duration: 0.09)
                    LinearKeyframe(3, duration: 0.09)
                    LinearKeyframe(0, duration: 0.18)
                    LinearKeyframe(0, duration: 3.0)
                }
            }
    }

    private struct Values {
        var scale: CGFloat = 1.0
        var brightness: Double = 0.0
        var offsetX: CGFloat = 0
    }
}

extension View {
    func loudBounce() -> some View {
        modifier(LoudBounceModifier())
    }
}
