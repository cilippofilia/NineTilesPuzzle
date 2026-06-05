//
//  PreviewTimePickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct PreviewTimePickerView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, value: Double)] = [
        ("Off", 0),
        ("1 second", 1),
        ("3 seconds", 3),
        ("5 seconds", 5),
        ("10 seconds", 10)
    ]

    var body: some View {
        List {
            ForEach(options, id: \.value) { option in
                Button {
                    state.setPreviewDuration(option.value)
                    dismiss()
                } label: {
                    LabeledContent {
                        if state.previewDuration == option.value {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    } label: {
                        Text(option.label)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Preview Time")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PreviewTimePickerView()
            .environment(PuzzleState())
    }
}
