//
//  ImagePreviewView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct ImagePreviewView: View {
    let image: CGImage
    let duration: Double
    let isFogMode: Bool
    let onSkip: () -> Void

    @State private var progress: Double = 1.0
    @State private var isRevealed = false

    /// In Fog Mode the image starts hidden; the user shakes to reveal it.
    /// In all other modes the image is immediately visible.
    private var showFog: Bool { isFogMode && !isRevealed }

    var body: some View {
        VStack {
            Spacer()

            Image(decorative: image, scale: 1.0)
                .resizable()
                .scaledToFit()
                .blur(radius: showFog ? 18 : 0)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    if showFog {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.45))
                        FogTileOverlay(seed: 99)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .animation(.easeInOut(duration: 1.2), value: showFog)
                .padding(.horizontal)

            Spacer()
        }
        // Badge floats above the image without affecting its vertical position
        .overlay(alignment: .top) {
            if isFogMode {
                if !isRevealed {
                    Label("Shake to reveal", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: .capsule)
                        .loudBounce()
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .padding(.top)
                } else {
                    Text("Memorize the image")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .padding(.top)
                }
            } else {
                Text("Memorize the image")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.top)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isRevealed)
        .background(ShakeDetector {
            guard isFogMode, !isRevealed else { return }
            withAnimation { isRevealed = true }
        })
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                CountdownBar(progress: progress)
                    .padding(.horizontal)
                    .animation(.linear(duration: duration), value: progress)
                Button("Skip", action: onSkip)
                    .foregroundStyle(.primary)
                    .buttonStyle(.bordered)
            }
            .padding(.bottom)
        }
        .onAppear {
            progress = 0
        }
    }
}

private struct CountdownBar: View {
    let progress: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.quaternary)
            Capsule()
                .foregroundStyle(.blue)
                .scaleEffect(x: progress, anchor: .leading)
        }
        .frame(height: 4)
    }
}
