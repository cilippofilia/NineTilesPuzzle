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
    case photoSourcePicker
}

struct MenuView: View {
    @Environment(PuzzleState.self) private var state
    @State private var path: [GameRoute] = []

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
                        allTimeHigh: state.allTimeHighStreak
                    )
                    .frame(height: 88)

                    Button {
                        path.append(.gridSizePicker)
                    } label: {
                        HStack {
                            LabeledContent("Difficulty", value: "\(state.difficultyLabel)  \(state.gridSize) × \(state.gridSize)")
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .foregroundStyle(.primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))

                    Button {
                        path.append(.photoSourcePicker)
                    } label: {
                        HStack {
                            LabeledContent("Photo source", value: state.imageSourceType.label)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .foregroundStyle(.primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .game:
                    PuzzleView()
                case .gridSizePicker:
                    GridSizePickerView()
                case .photoSourcePicker:
                    PhotoSourcePickerView()
                }
            }
        }
    }
}

#Preview {
    MenuView()
        .environment(PuzzleState())
}
