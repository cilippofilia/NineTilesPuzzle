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
    let onSkip: () -> Void

    @State private var progress: Double = 1.0
    @State private var isRevealed = false

    var body: some View {
        VStack {
            Spacer()

            if !isRevealed {
                Label("Shake to reveal", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: .capsule)
                    .loudBounce()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Text("Memorize the image")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Image(decorative: image, scale: 1.0)
                .resizable()
                .scaledToFit()
                .blur(radius: isRevealed ? 0 : 18)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    if !isRevealed {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.45))
                        FogTileOverlay(seed: 99)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .animation(.easeInOut(duration: 1.2), value: isRevealed)
                .padding(.horizontal)
                .padding(.top, 12)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.4), value: isRevealed)
        .background(ShakeDetector {
            guard !isRevealed else { return }
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
