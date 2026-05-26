//
//  PuzzleView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleView: View {
    @Environment(PuzzleState.self) private var state
    @State private var isShowingWinAlert = false

    var body: some View {
        VStack {
            if state.isLoading {
                LoadingView()
            } else if let error = state.error {
                PuzzleErrorView(error: error, onRetry: startNewGame)
            } else {
                PuzzleGridView()
            }
        }
        .onChange(of: state.isSolved) { _, solved in
            if solved { isShowingWinAlert = true }
        }
        .alert("Puzzle complete!", isPresented: $isShowingWinAlert) {
            Button("Play again", action: startNewGame)
        }
    }

    private func startNewGame() {
        Task { await state.startNewGame() }
    }
}

#Preview {
    PuzzleView()
        .environment(PuzzleState())
}
