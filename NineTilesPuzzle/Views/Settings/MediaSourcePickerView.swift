//
//  MediaSourcePickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import Photos
import SwiftUI
import UIKit

struct MediaSourcePickerView: View {
    @Environment(GameSession.self) private var session
    @Environment(\.openURL) private var openURL

    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        List {
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

            // Only offered when the device actually has a camera — greyed out entirely on
            // hardware (or the Simulator) that can't shoot, the same way Numbers is Slide-only.
            if QuickSnapCameraSession.isCameraAvailable {
                MediaSourceRowView(
                    title: MediaSourceType.camera.label,
                    subtitle: "Snap whatever's in front of you on a countdown — no retakes",
                    isSelected: session.mediaSourceType == .camera
                ) {
                    session.setMediaSourceType(.camera)
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
        }
        .navigationTitle("Media")
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
        MediaSourcePickerView()
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore(), powerUpStore: PowerUpStore()))
    }
}
