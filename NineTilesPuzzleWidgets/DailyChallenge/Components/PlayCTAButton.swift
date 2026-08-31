//
//  PlayCTAButton.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// A solid gradient "Play" pill replacing the original's plain accent-colored `Label`.
struct PlayCTAButton: View {
    var body: some View {
        Label("Play", systemImage: "play.fill")
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(BrandGradient.diagonal, in: .capsule)
    }
}
