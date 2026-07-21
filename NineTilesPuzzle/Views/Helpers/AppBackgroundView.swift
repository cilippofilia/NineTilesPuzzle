//
//  AppBackgroundView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// Ambient app background — an animated mesh-gradient bloom in the top corners over
/// near-black, scattered puzzle-piece watermarks (two tinted red and gold to match the
/// glow), and a fade to solid black toward the bottom so foreground content stays legible.
/// The "Duotone" glow treatment from the marketing site's `.aurora` background, reproduced
/// natively so it scales to any device. Used behind both the main menu and the paywall.
struct AppBackgroundView: View {
    private static let base = Color(red: 0x06 / 255, green: 0x06 / 255, blue: 0x0a / 255)
    private static let ember = Color(red: 0xff / 255, green: 0x3d / 255, blue: 0x5e / 255)
    private static let gold = Color(red: 0xff / 255, green: 0xd2 / 255, blue: 0x3d / 255)

    var body: some View {
        ZStack {
            Self.base

            AppAnimatedGlowMesh()

            AppDriftingPuzzlePiece(
                rotation: -18, tint: Self.ember, opacity: 0.12, alignment: .topLeading, offsetX: 0.16, offsetY: 0.1,
                driftDuration: 8, driftDelay: 0
            )
            AppDriftingPuzzlePiece(
                rotation: 24, size: 90, tint: Self.gold, opacity: 0.12,
                alignment: .topTrailing, offsetX: -0.06, offsetY: 0.05,
                driftDuration: 9.5, driftDelay: 1.2
            )
            AppDriftingPuzzlePiece(
                rotation: 10, alignment: .bottomLeading, offsetX: 0.1, offsetY: -0.32,
                driftDuration: 10, driftDelay: 0.6
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.38),
                    .init(color: Self.base.opacity(0.75), location: 0.72),
                    .init(color: .black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AppBackgroundView()
}
