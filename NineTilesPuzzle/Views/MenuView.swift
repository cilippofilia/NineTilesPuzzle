//
//  MenuView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI

enum GameRoute: Hashable {
    case game
    case gridSizePicker
}

struct MenuView: View {
    @Environment(PuzzleState.self) private var state
    @State private var path: [GameRoute] = []
    @State private var showStats = false
    @State private var showSettings = false

    var puzzleColor: LinearGradient {
        LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Spacer()

                HStack(spacing: 0) {
                    Image(systemName: "puzzlepiece.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 44)
                        .rotationEffect(Angle(degrees: -45))
                        .foregroundStyle(puzzleColor)

                    Text("Nine Tiles")
                        .font(.largeTitle)
                        .bold()
                }
                .padding()

                VStack(spacing: 12) {
                    StreakStatsView(
                        currentStreak: state.currentStreak,
                        allTimeHigh: state.allTimeHighStreak,
                        personalBestMoves: state.personalBestForCurrentSize
                    )
                    .frame(height: 88)

                    Button {
                        path.append(.gridSizePicker)
                    } label: {
                        HStack {
                            LabeledContent("Difficulty", value: state.difficultyDisplayValue)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .foregroundStyle(.primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))

                    HStack(spacing: 12) {
                        Button {
                            showStats = true
                        } label: {
                            Label("Stats", systemImage: "chart.bar.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .contentShape(.rect(cornerRadius: 20))
                        }
                        .foregroundStyle(.primary)
                        .background(.quaternary, in: .rect(cornerRadius: 20))

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .contentShape(.rect(cornerRadius: 20))
                        }
                        .foregroundStyle(.primary)
                        .background(.quaternary, in: .rect(cornerRadius: 20))
                    }
                }
                .padding(.horizontal)

                Button("Play") {
                    path.append(.game)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()

                Spacer()
            }
            .sheet(isPresented: $showStats) {
                StatsView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .game:
                    PuzzleView()
                case .gridSizePicker:
                    GridSizePickerView()
                }
            }
        }
    }
}

#Preview {
    MenuView()
        .environment(PuzzleState())
}
