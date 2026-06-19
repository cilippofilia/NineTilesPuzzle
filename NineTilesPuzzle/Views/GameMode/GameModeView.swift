//
//  GameModeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import Photos
import SwiftUI
import UIKit

struct GameModeView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(\.openURL) private var openURL

    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        List {
            Section("Game Type") {
                ForEach(GameMode.allCases) { mode in
                    if mode.isAvailable {
                        Button {
                            state.setGameMode(mode)
                        } label: {
                            GameModeRowView(mode: mode, isSelected: state.selectedGameMode == mode)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        GameModeRowView(mode: mode, isSelected: false)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                MediaSourceRowView(
                    title: MediaSourceType.random.label,
                    subtitle: "A new image from the internet each game",
                    isSelected: state.mediaSourceType == .random
                ) {
                    state.setMediaSourceType(.random)
                }

                MediaSourceRowView(
                    title: MediaSourceType.local.label,
                    subtitle: "A random photo from your library",
                    isSelected: state.mediaSourceType == .local
                ) {
                    state.setMediaSourceType(.local)
                    requestPhotoAccess()
                }

                MediaSourceRowView(
                    title: MediaSourceType.mixed.label,
                    subtitle: "Randomly picks internet or your library each game",
                    isSelected: state.mediaSourceType == .mixed
                ) {
                    state.setMediaSourceType(.mixed)
                    requestPhotoAccess()
                }

                if state.selectedGameMode == .slide {
                    MediaSourceRowView(
                        title: MediaSourceType.numbers.label,
                        subtitle: "No picture — tiles show the number they belong at",
                        isSelected: state.mediaSourceType == .numbers
                    ) {
                        state.setMediaSourceType(.numbers)
                    }
                }

                if authStatus == .limited {
                    Button("Update Photo Access in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .foregroundStyle(.tint)
                }
            } header: {
                Text("Media")
            } footer: {
                Text("What the tiles are made of — a photo, or just their numbers.")
            }
        }
        .navigationTitle("Game Modes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
    }

    private func requestPhotoAccess() {
        Task {
            authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
    }
}

private struct GameModeRowView: View {
    let mode: GameMode
    let isSelected: Bool

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    HStack {
                        Text(mode.title)
                        if !mode.isAvailable {
                            Text("(Coming soon…)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: mode.icon)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }
}

private struct MediaSourceRowView: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                MediaSourceLabelView(title: title, subtitle: subtitle, isSelected: isSelected)
            }
            .foregroundStyle(.primary)
        } else {
            MediaSourceLabelView(title: title, subtitle: subtitle, isSelected: isSelected)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MediaSourceLabelView: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        LabeledContent {
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        } label: {
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GameModeView()
            .environment(PuzzleState())
    }
}
