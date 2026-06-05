//
//  ImagePreviewView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct ImagePreviewView: View {
    let image: CGImage
    let onSkip: () -> Void

    @State private var progress: Double = 1.0

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(decorative: image, scale: 1.0)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 12))
                .padding(.horizontal)

            CountdownBar(progress: progress)
                .padding(.horizontal)
                .animation(.linear(duration: 3), value: progress)

            Text("Memorize the image")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Skip", action: onSkip)
                .foregroundStyle(.primary)
                .buttonStyle(.bordered)

            Spacer()
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
