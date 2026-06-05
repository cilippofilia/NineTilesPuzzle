//
//  PuzzleView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleView: View {
    @Environment(PuzzleState.self) private var state
    @State private var showCompletion = false
    @State private var showNewRecord = false

    var body: some View {
        ZStack {
            VStack {
                if state.isLoading {
                    LoadingView()
                } else if let error = state.error {
                    PuzzleErrorView(error: error, onRetry: startNewGame)
                } else {
                    Spacer()
                    StreakCounterView(currentStreak: state.currentStreak)
                        .opacity(showCompletion ? 0 : 1)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showCompletion)
                    PuzzleGridView()
                    Spacer()
                }
            }
            .animation(.none, value: state.isLoading)

            VStack {
                CompletionBannerView(streak: state.currentStreak, isNewRecord: showNewRecord)
                    .padding(.top)
                    .offset(y: showCompletion ? 0 : -300)
                    .opacity(showCompletion ? 1 : 0)

                Spacer()

                Button("Continue", action: startNewGame)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom)
                    .offset(y: showCompletion ? 0 : 300)
                    .opacity(showCompletion ? 1 : 0)
            }
            .allowsHitTesting(showCompletion)
        }
        .task {
            await state.startNewGame()
        }
        .onChange(of: state.isSolved) { _, solved in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(solved ? 0.3 : 0)) {
                showCompletion = solved
            }
        }
        .onChange(of: state.isNewRecord) { _, isRecord in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showNewRecord = isRecord
            }
        }
        .navigationTitle("Puzzle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startNewGame() {
        Task { await state.startNewGame() }
    }
}

#Preview {
    PuzzleView()
        .environment(PuzzleState())
}
