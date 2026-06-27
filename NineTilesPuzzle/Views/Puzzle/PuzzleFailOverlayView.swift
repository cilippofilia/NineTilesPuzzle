//
//  PuzzleFailOverlayView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// Shared scaffold for the Time Trial and Limited Moves "you lost" overlays, which differ
/// only in their summary content: a banner that drops in from the top, and a "Try Again"
/// button that rises from the bottom, both mutually exclusive with the completion banner.
/// The slide/fade is driven by whatever animated state flips `isShowing`.
struct PuzzleFailOverlayView<Content: View>: View {
    let isShowing: Bool
    let onTryAgain: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            content
                .padding(.top)
                .padding(.horizontal)
                .offset(y: isShowing ? 0 : -300)
                .opacity(isShowing ? 1 : 0)

            Spacer()

            Button("Try Again", action: onTryAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom)
                .offset(y: isShowing ? 0 : 300)
                .opacity(isShowing ? 1 : 0)
        }
        .allowsHitTesting(isShowing)
    }
}
