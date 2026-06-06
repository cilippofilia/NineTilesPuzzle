//
//  GridSizePickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/3/26.
//

import SwiftUI

struct GridSizePickerView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private let sizes = Array(3...8)

    private func label(for size: Int) -> String {
        switch size {
        case 3: "Easy"
        case 4: "Medium"
        case 5: "Hard"
        case 6: "Expert"
        case 7: "Master"
        default: "Insane"
        }
    }

    var body: some View {
        List {
            Button {
                state.setRandomSize()
                dismiss()
            } label: {
                LabeledContent {
                    if state.useRandomSize {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                } label: {
                    HStack {
                        Text("Random")
                        Image(systemName: "shuffle")
                    }
                }
            }
            .foregroundStyle(.primary)

            ForEach(sizes, id: \.self) { size in
                Button {
                    state.setGridSize(size)
                    dismiss()
                } label: {
                    LabeledContent {
                        if !state.useRandomSize && state.gridSize == size {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    } label: {
                        Text("\(label(for: size))  \(size) × \(size)")
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Difficulty")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GridSizePickerView()
            .environment(PuzzleState())
    }
}
