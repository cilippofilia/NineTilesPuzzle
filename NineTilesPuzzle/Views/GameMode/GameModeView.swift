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
    @Environment(GameSession.self) private var session
    @Environment(\.openURL) private var openURL

    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        List {
            Section {
                ForEach(GameMode.allCases) { mode in
                    if mode.isAvailable {
                        Button {
                            session.setGameMode(mode)
                        } label: {
                            GameModeRowView(mode: mode, isSelected: session.selectedGameMode == mode)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        GameModeRowView(mode: mode, isSelected: false)
                            .foregroundStyle(.secondary)
                    }

                    if mode == .timeTrial && session.selectedGameMode == .timeTrial {
                        HStack {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Gauntlet Ladder")
                                    Text("10 escalating stages with fixed grid sizes. Difficulty is set automatically while active.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "figure.stairs")
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Toggle("Gauntlet Ladder", isOn: Binding(
                                get: { session.isLadderMode },
                                set: { session.setLadderMode($0) }
                            ))
                            .labelsHidden()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } header: {
                Text("Game Type")
            }

            Section {
                MediaSourceRowView(
                    title: MediaSourceType.random.label,
                    subtitle: "A new image from the internet each game",
                    isSelected: session.mediaSourceType == .random
                ) {
                    session.setMediaSourceType(.random)
                }

                MediaSourceRowView(
                    title: MediaSourceType.local.label,
                    subtitle: "A random photo from your library",
                    isSelected: session.mediaSourceType == .local
                ) {
                    session.setMediaSourceType(.local)
                    requestPhotoAccess()
                }

                MediaSourceRowView(
                    title: MediaSourceType.mixed.label,
                    subtitle: "Randomly picks internet or your library each game",
                    isSelected: session.mediaSourceType == .mixed
                ) {
                    session.setMediaSourceType(.mixed)
                    requestPhotoAccess()
                }

                if session.selectedGameMode == .slide {
                    MediaSourceRowView(
                        title: MediaSourceType.numbers.label,
                        subtitle: "No picture — tiles show the number they belong at",
                        isSelected: session.mediaSourceType == .numbers
                    ) {
                        session.setMediaSourceType(.numbers)
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

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    NavigationStack {
        GameModeView()
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings))
    }
}
