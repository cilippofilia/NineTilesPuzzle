//
//  AppAnimatedGlowMesh.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// The ambient warm glow behind `AppBackgroundView` — a 3x3 `MeshGradient` whose control
/// points and colors slowly drift between two states in a forever-repeating loop, so the
/// light itself feels alive rather than two fixed, static blurred circles.
struct AppAnimatedGlowMesh: View {
    private static let ember = Color(red: 0xff / 255, green: 0x3d / 255, blue: 0x5e / 255)
    private static let gold = Color(red: 0xff / 255, green: 0xd2 / 255, blue: 0x3d / 255)

    private static let pointsA: [SIMD2<Float>] = [
        [0.0, 0.0], [0.5, -0.06], [1.0, 0.0],
        [-0.08, 0.42], [0.5, 0.38], [1.08, 0.42],
        [0.1, 1.0], [0.5, 1.0], [0.9, 1.0]
    ]
    private static let pointsB: [SIMD2<Float>] = [
        [-0.06, 0.08], [0.5, 0.02], [1.06, -0.05],
        [0.0, 0.36], [0.5, 0.5], [1.0, 0.34],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
    ]

    private static let colorsA: [Color] = [
        ember.opacity(0.55), ember.opacity(0.3), gold.opacity(0.4),
        ember.opacity(0.24), .clear, gold.opacity(0.2),
        .clear, .clear, .clear
    ]
    private static let colorsB: [Color] = [
        ember.opacity(0.4), gold.opacity(0.28), gold.opacity(0.55),
        ember.opacity(0.3), .clear, gold.opacity(0.32),
        .clear, .clear, .clear
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAlternate = false

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: isAlternate ? Self.pointsB : Self.pointsA,
            colors: isAlternate ? Self.colorsB : Self.colorsA
        )
        .blur(radius: 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                isAlternate = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0x06 / 255, green: 0x06 / 255, blue: 0x0a / 255)
        AppAnimatedGlowMesh()
    }
    .ignoresSafeArea()
}
