//
//  TimeTrialResumeOverlay.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/16/26.
//

import SwiftUI

/// Full-board dimming overlay shown when a Time Trial / Gauntlet Ladder puzzle returns to the
/// foreground after backgrounding or a system interruption. `GameSession.resumeTimers()` is
/// deliberately delayed until this counts down to zero, so the countdown clock doesn't start
/// ticking again the instant the screen becomes visible, before the player has had a beat to
/// reorient.
struct TimeTrialResumeOverlay: View {
    let isShowing: Bool
    let value: Int

    var body: some View {
        ZStack {
            Color.black.opacity(isShowing ? 0.75 : 0)

            VStack(spacing: 12) {
                Text("Get Ready")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(value, format: .number)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
            }
            .opacity(isShowing ? 1 : 0)
            .scaleEffect(isShowing ? 1 : 0.8)
        }
        .animation(.easeInOut(duration: 0.25), value: isShowing)
        .allowsHitTesting(isShowing)
        .ignoresSafeArea()
    }
}
