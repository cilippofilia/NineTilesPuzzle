//
//  HomeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI

struct HomeView: View {
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
                    LabeledContent("Size", value: "3 × 3")
                        .padding()
                    LabeledContent("Photo source", value: "Random")
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
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(PuzzleState())
}
