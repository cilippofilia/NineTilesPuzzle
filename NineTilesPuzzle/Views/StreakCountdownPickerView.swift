//
//  StreakCountdownPickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import SwiftUI

struct StreakCountdownPickerView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, value: Double)] = [
        ("Off", 0),
        ("15 seconds", 15),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120)
    ]

    var body: some View {
        List {
            ForEach(options, id: \.value) { option in
                Button {
                    state.setStreakCountdownDuration(option.value)
                    dismiss()
                } label: {
                    LabeledContent {
                        if state.streakCountdownDuration == option.value {
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
        .navigationTitle("Streak Countdown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StreakCountdownPickerView()
            .environment(PuzzleState())
    }
}
