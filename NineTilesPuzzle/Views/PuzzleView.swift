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
            // Layer 1: centered main content — only Spacer/content/Spacer so centering
            // is never affected by supplementary elements in other layers
            VStack {
                if state.isLoading {
                    LoadingView()
                        .transition(.opacity)
                } else if state.isPreviewing, let image = state.sourceImage {
                    ImagePreviewView(image: image, onSkip: state.skipPreview)
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                } else if let error = state.error {
                    PuzzleErrorView(error: error, onRetry: startNewGame)
                        .transition(.opacity)
                } else {
                    Spacer()
                    PuzzleGridView()
                        .clipShape(.rect(cornerRadius: 12))
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .identity
                        ))
                    Spacer()
                }
            }
            .animation(.easeInOut(duration: 0.35), value: state.isLoading)
            .animation(.easeInOut(duration: 0.35), value: state.isPreviewing)

            // Layer 2: streak counter floats at top — outside layout flow so it
            // doesn't shift the grid's vertical center
            VStack {
                StreakCounterView(currentStreak: state.currentStreak, bestStreak: state.allTimeHighStreak, timerRemaining: state.timerRemaining, isTimerRunning: state.isTimerRunning)
                    .padding(.top)
                    .opacity(streakVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: state.isLoading)
                    .animation(.easeInOut(duration: 0.35), value: state.isPreviewing)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showCompletion)
                Spacer()
            }

            // Layer 3: completion overlay
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
        .sensoryFeedback(.success, trigger: state.isSolved) { _, newValue in
            newValue
        }
        .sensoryFeedback(.warning, trigger: state.didBreakStreak)
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

    private var streakVisible: Bool {
        !showCompletion && !state.isLoading && state.error == nil
    }

    private func startNewGame() {
        Task { await state.startNewGame() }
    }
}

#Preview {
    PuzzleView()
        .environment(PuzzleState())
}
