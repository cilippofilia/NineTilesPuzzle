//
//  SplashScreenView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct SplashScreenView: View {
    let onComplete: () -> Void

    @State private var iconScale: CGFloat = 0.2
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -90
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 24
    @State private var containerOpacity: Double = 1

    private var puzzleGradient: LinearGradient {
        LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()

            VStack {
                Image(systemName: "puzzlepiece.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(iconRotation))
                    .foregroundStyle(puzzleGradient)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                Text("Nine Tiles")
                    .font(.largeTitle)
                    .bold()
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
            }
        }
        .opacity(containerOpacity)
        .task {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
                iconRotation = -45
            }
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.5)) {
                containerOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.55))
            onComplete()
        }
    }
}

#Preview {
    SplashScreenView {}
}
