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
    @Environment(StoreManager.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var paywallContext: PaywallContext?

    var body: some View {
        List {
            MediaSourceRowView(
                title: MediaSourceType.numbers.label,
                subtitle: "No picture — tiles show the number they belong at",
                isSelected: session.mediaSourceType == .numbers
            ) {
                session.setMediaSourceType(.numbers)
            }

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
                isSelected: session.mediaSourceType == .local,
                isLocked: isLocked(.local)
            ) {
                selectOrGate(.local) {
                    session.setMediaSourceType(.local)
                    requestPhotoAccess()
                }
            }

            MediaSourceRowView(
                title: MediaSourceType.mixed.label,
                subtitle: "Randomly picks internet or your library each game",
                isSelected: session.mediaSourceType == .mixed,
                isLocked: isLocked(.mixed)
            ) {
                selectOrGate(.mixed) {
                    session.setMediaSourceType(.mixed)
                    requestPhotoAccess()
                }
            }

            // Only offered when the device actually has a camera — greyed out entirely on
            // hardware (or the Simulator) that can't shoot.
            if QuickSnapCameraSession.isCameraAvailable {
                MediaSourceRowView(
                    title: MediaSourceType.camera.label,
                    subtitle: "Snap whatever's in front of you on a countdown — no retakes",
                    isSelected: session.mediaSourceType == .camera,
                    isLocked: isLocked(.camera)
                ) {
                    selectOrGate(.camera) {
                        session.setMediaSourceType(.camera)
                    }
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
        .paywallSheet(context: $paywallContext)
    }

    private func isLocked(_ source: MediaSourceType) -> Bool {
        PremiumFeature.imageSource(source).isLocked(isPremiumUnlocked: store.isPremiumUnlocked)
    }

    /// Runs `select` if `source` isn't locked; otherwise presents the paywall instead.
    /// Locked sources never trigger a permission prompt or persist a selection.
    private func selectOrGate(_ source: MediaSourceType, select: () -> Void) {
        if isLocked(source) {
            paywallContext = .imageSource(source)
        } else {
            select()
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
            .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: DailyChallengeStore(), powerUpStore: PowerUpStore(), challengeStore: ChallengeStore()))
            .environment(StoreManager())
    }
}
