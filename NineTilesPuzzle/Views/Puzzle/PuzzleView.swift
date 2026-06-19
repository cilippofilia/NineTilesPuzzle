//
//  PuzzleView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(SoundService.self) private var soundService
    @Environment(\.dismiss) private var dismiss
    @State private var showCompletion = false
    @State private var showNewRecord = false
    @State private var showNewMovesRecord = false
    @State private var showNewBestTime = false
    @State private var showQuitAlert = false
    @State private var bannerOffset: CGSize = .zero
    @State private var isSolving = false

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
                    PuzzleGridView(showReveal: showCompletion)
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

            // Layer 2: streak counter + move counter float at top — outside layout flow so
            // they don't shift the grid's vertical center
            VStack {
                PuzzleStatusBarView(
                    gameMode: state.selectedGameMode,
                    debugOverlayEnabled: state.debugOverlayEnabled,
                    currentStreak: state.currentStreak,
                    bestStreak: state.allTimeHighStreak,
                    timerRemaining: state.timerRemaining,
                    isTimerRunning: state.isTimerRunning,
                    moveCount: state.currentMoveCount,
                    personalBest: state.personalBestForCurrentSize,
                    elapsedTime: state.elapsedTime,
                    personalBestTime: state.personalBestTimeForCurrentSize
                )
                .frame(maxWidth: .infinity)
                .padding(.top)
                .opacity(streakVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.35), value: state.isLoading)
                .animation(.easeInOut(duration: 0.35), value: state.isPreviewing)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showCompletion)
                Spacer()
            }

            // Layer 3: completion overlay
            VStack {
                CompletionBannerView(gameMode: state.selectedGameMode, streak: state.currentStreak, isNewRecord: showNewRecord, moveCount: state.currentMoveCount, personalBest: state.personalBestForCurrentSize, elapsedTime: state.elapsedTime, personalBestTime: state.personalBestTimeForCurrentSize, isPracticeMode: state.debugOverlayEnabled)
                    .padding(.top)
                    .padding(.horizontal)
                    .offset(x: bannerOffset.width, y: (showCompletion ? 0 : -300) + bannerOffset.height)
                    .opacity(showCompletion ? 1 : 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    bannerOffset = value.translation
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    bannerOffset = .zero
                                }
                            }
                    )

                // Floats below the banner as its own layer — rather than growing the
                // banner's card — and slides down out from behind it on appear.
                if showCompletion && hasNewBestBadge {
                    NewBestBadgesView(
                        showsStreak: state.selectedGameMode != .slide,
                        moveCount: state.currentMoveCount,
                        isNewMovesRecord: showNewMovesRecord,
                        elapsedTime: state.elapsedTime,
                        isNewBestTime: showNewBestTime
                    )
                    .padding(.horizontal)
                    .offset(bannerOffset)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                Button("Continue", action: startNewGame)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom)
                    .offset(y: showCompletion ? 0 : 300)
                    .opacity(showCompletion ? 1 : 0)
            }
            .allowsHitTesting(showCompletion)

            // Layer 4: achievement unlock toast — only shown mid-game to avoid overlapping the completion banner
            if let achievement = state.newlyUnlockedAchievement, !state.isSolved {
                VStack {
                    Spacer()
                    AchievementToastView(achievement: achievement)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.newlyUnlockedAchievement)
        .task(id: state.newlyUnlockedAchievement?.id) {
            guard state.newlyUnlockedAchievement != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            await state.dismissAchievementNotification()
        }
        .task(id: state.isSolved) {
            guard state.isSolved else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeInOut(duration: 0.35)) {
                showNewRecord = false
                showNewMovesRecord = false
                showNewBestTime = false
            }
        }
        .task {
            await state.startNewGame()
        }
        .sensoryFeedback(.success, trigger: state.isSolved) { _, newValue in
            newValue && state.hapticsEnabled
        }
        .sensoryFeedback(.warning, trigger: state.didBreakStreak) { _, _ in
            state.hapticsEnabled
        }
        .onChange(of: state.isSolved) { _, solved in
            if solved { soundService.playCompletion() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(solved ? 0.3 : 0)) {
                showCompletion = solved
            }
        }
        .onChange(of: state.isNewRecord) { _, isRecord in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showNewRecord = isRecord
            }
        }
        .onChange(of: state.isNewMovesRecord) { _, isRecord in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showNewMovesRecord = isRecord
            }
        }
        .onChange(of: state.isNewBestTime) { _, isRecord in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showNewBestTime = isRecord
            }
        }
        .navigationTitle("Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isGameActive)
        .toolbar {
            if isGameActive {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        showQuitAlert = true
                    }
                }
            }

            if showSolveButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Solve", systemImage: "wand.and.stars", action: solvePuzzle)
                        .disabled(isSolving)
                }
            }
        }
        .alert("Quit this run?", isPresented: $showQuitAlert) {
            Button("Quit", role: .destructive) {
                state.leaveGame()
                dismiss()
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("Your progress on this puzzle will be lost.")
        }
        .onDisappear {
            state.leaveGame()
        }
    }

    private var isGameActive: Bool {
        (!state.tiles.isEmpty || state.isPreviewing) && !state.isSolved
    }

    private var showSolveButton: Bool {
        let result = state.debugOverlayEnabled
            && state.selectedGameMode == .slide
            && !state.tiles.isEmpty
            && !state.isSolved
        return result
    }

    private var streakVisible: Bool {
        !showCompletion && !state.isLoading && state.error == nil
    }

    private var hasNewBestBadge: Bool {
        showNewMovesRecord || (state.selectedGameMode == .slide && showNewBestTime)
    }

    private func startNewGame() {
        bannerOffset = .zero
        Task { await state.startNewGame() }
    }

    /// Debug-only: walks the puzzle to its solved state, one slide at a time, so the slide
    /// mode's win condition and animations can be verified end to end.
    private func solvePuzzle() {
        guard !isSolving else { return }
        isSolving = true

        let moves = SlideSolver().solve(tiles: state.tiles, gridSize: state.gridSize)

        Task {
            for move in moves {
                guard !state.isSolved else {
                    break
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = state.slideTile(from: move)
                }
                soundService.playTileClick()
                try? await Task.sleep(for: .milliseconds(120))
            }
            isSolving = false
        }
    }
}

#Preview {
    PuzzleView()
        .environment(PuzzleState())
        .environment(SoundService())
}
