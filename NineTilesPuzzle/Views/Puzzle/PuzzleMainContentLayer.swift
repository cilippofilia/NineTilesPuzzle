//
//  PuzzleMainContentLayer.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// `PuzzleView`'s centered base layer: only Spacer/content/Spacer so the grid's vertical
/// centering is never affected by the supplementary elements floating in other ZStack
/// layers. Shows the loading spinner, image preview, error state, or the grid itself.
struct PuzzleMainContentLayer: View {
    @Environment(GameSession.self) private var session
    let completion: PuzzleCompletionViewModel
    let startNewGame: () -> Void
    let switchToPhotosAndRetry: () -> Void

    var body: some View {
        VStack {
            if session.isLoading {
                LoadingView()
                    // Removal is instant rather than fading, so this never lingers
                    // on screen crossfaded over the preview/grid that replaces it.
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
            } else if session.isPreviewing, let image = session.previewImage {
                ImagePreviewView(image: image, duration: session.currentPreviewDuration, isFogMode: session.isFogMode, isDailyChallenge: session.isDailyGameActive, gameMode: session.selectedGameMode, onSkip: session.skipPreview)
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
            } else if let error = session.error {
                PuzzleErrorView(error: error, onRetry: startNewGame, onSwitchToPhotos: switchToPhotosAndRetry)
                    .transition(.opacity)
            } else {
                Spacer()
                PuzzleGridView(showReveal: completion.showCompletion)
                    .clipShape(.rect(cornerRadius: 12))
                    // Zen mode's only acknowledgment that a puzzle is done: the finished
                    // picture takes one slow, soft breath, with a little magic dust
                    // drifting around its edge, before the next one quietly arrives.
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(colors: [.teal, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 4
                            )
                            .blur(radius: 7)
                            .opacity(session.isZenMode ? completion.zenGlowOpacity : 0)
                    }
                    .overlay {
                        GeometryReader { proxy in
                            ForEach(completion.zenSparkles) { sparkle in
                                ZenSparkleView(size: sparkle.size, color: sparkle.color, delay: sparkle.delay)
                                    .position(x: sparkle.x * proxy.size.width, y: sparkle.y * proxy.size.height)
                            }
                        }
                        .opacity(session.isZenMode ? completion.zenGlowOpacity : 0)
                        .allowsHitTesting(false)
                    }
                    .shadow(color: .teal.opacity(session.isZenMode ? completion.zenGlowOpacity * 0.7 : 0), radius: 28)
                    .scaleEffect(session.isZenMode ? completion.zenBreathScale : 1)
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .identity
                    ))
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.isLoading)
        .animation(.easeInOut(duration: 0.35), value: session.isPreviewing)
    }
}
