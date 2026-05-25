//
//  PuzzleView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleView: View {
    @State private var state = PuzzleState()

    var body: some View {
        Group {
            if state.isLoading {
                ProgressView()
            } else if let image = state.sourceImage {
                Image(
                    image,
                    scale: 1.0,
                    orientation: .up,
                    label: Text("Puzzle image")
                )
                .resizable()
                .scaledToFit()
            } else if let error = state.error {
                ContentUnavailableView(
                    "Failed to load image",
                    systemImage: "photo",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .task {
            await state.startNewGame()
        }
    }
}

#Preview {
    PuzzleView()
}
