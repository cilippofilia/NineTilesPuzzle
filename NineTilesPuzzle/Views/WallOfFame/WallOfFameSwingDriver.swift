//
//  WallOfFameSwingDriver.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/28/26.
//

import SwiftUI

/// Invisible view whose sole job is to tick the shared `WallOfFameSwingEngine`
/// once per frame from the latest device roll. A single `TimelineView` here
/// replaces the per-card ones, and because it only renders `Color.clear` the
/// cards are not rebuilt every frame — each updates solely when its own swing
/// `angle` changes.
struct WallOfFameSwingDriver: View {
    let engine: WallOfFameSwingEngine
    let motionManager: MotionManager

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: false)) { timeline in
            Color.clear
                .onChange(of: timeline.date) { _, _ in
                    engine.step(roll: motionManager.roll)
                }
        }
        .allowsHitTesting(false)
    }
}
