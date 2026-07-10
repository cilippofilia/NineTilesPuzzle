//
//  MenuRow.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/10/26.
//

import SwiftUI

/// One tappable settings-style row: title/icon on the left, an optional detail value and
/// chevron on the right. `isEnabled` also hides the chevron, matching the Grid Size row's
/// look when grid size is locked by Gauntlet Ladder mode.
struct MenuRow: View {
    let title: String
    let systemImage: String
    var detail: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if let detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                }
                if isEnabled {
                    Image(systemName: "chevron.forward")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .contentShape(.rect)
        }
        .foregroundStyle(isEnabled ? .primary : .secondary)
        .disabled(!isEnabled)
    }
}
