//
//  QuickSnapDurationPickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI

/// Lets the player choose how long the Quick Snap capture countdown runs before the frame is
/// auto-snapped. Mirrors `PreviewTimePickerView`; the shortest option matches the old hard-coded
/// three-second floor.
struct QuickSnapDurationPickerView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, value: Double)] = [
        ("3 seconds", 3),
        ("5 seconds", 5),
        ("10 seconds", 10)
    ]

    var body: some View {
        List {
            ForEach(options, id: \.value) { option in
                Button {
                    settings.setQuickSnapDuration(option.value)
                    dismiss()
                } label: {
                    LabeledContent {
                        if settings.quickSnapDuration == option.value {
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
        .navigationTitle("Quick Snap Timer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        QuickSnapDurationPickerView()
            .environment(SettingsStore())
    }
}
