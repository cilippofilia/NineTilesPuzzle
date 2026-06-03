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

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Spacer()

                Text("Nine Tiles")
                    .font(.largeTitle)
                    .bold()
                    .padding()

                Group {
                    Button {
                        path.append(.gridSizePicker)
                    } label: {
                        HStack {
                            LabeledContent("Difficulty", value: "\(state.difficultyLabel)  \(state.gridSize) × \(state.gridSize)")
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding()

                    Button {
                        path.append(.photoSourcePicker)
                    } label: {
                        HStack {
                            LabeledContent("Photo source", value: state.imageSourceType.label)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding()
                }
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
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
