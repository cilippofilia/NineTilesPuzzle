//
//  ZenSparkleView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import SwiftUI

/// A single twinkling fleck of dust. Twinkles continuously on its own clock; the parent
/// controls visibility by fading the whole cluster in and out, so each sparkle's twinkle
/// phase is already mid-cycle and offset from its neighbors the moment it appears.
struct ZenSparkleView: View {
    let size: CGFloat
    let color: Color
    let delay: Double

    @State private var twinkle = false

    var body: some View {
        Image(systemName: "sparkle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .scaleEffect(twinkle ? 1 : 0.4)
            .opacity(twinkle ? 1 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(delay)) {
                    twinkle = true
                }
            }
    }
}

#Preview {
    HStack(spacing: 20) {
        ZenSparkleView(size: 14, color: .teal, delay: 0)
        ZenSparkleView(size: 14, color: .mint, delay: 0.2)
        ZenSparkleView(size: 14, color: .teal, delay: 0.4)
    }
}
