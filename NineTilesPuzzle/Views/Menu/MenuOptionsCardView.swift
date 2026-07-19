//
//  MenuOptionsCardView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI

/// The menu's settings-style card: current mode/media/grid-size at a glance, plus entry points
/// into Achievements, Wall of Fame, and Challenge Friends.
struct MenuOptionsCardView: View {
    @Environment(GameSession.self) private var session
    @Environment(AchievementsStore.self) private var achievementsStore
    @Environment(SettingsStore.self) private var settings
    @Environment(StoreManager.self) private var store

    @Binding var path: [GameRoute]
    @State private var paywallContext: PaywallContext?

    var body: some View {
        VStack(spacing: 0) {
            if session.selectedGameMode != .zen {
                MenuStatsCardView()
                    .frame(height: 55)

                Divider()
            }

            MenuRow(title: "Game Mode", systemImage: "gamecontroller.fill", detail: session.selectedGameMode.title) {
                path.append(.gameModes)
            }

            Divider()

            MenuRow(title: "Media", systemImage: "photo.tv", detail: session.mediaSourceType.label) {
                path.append(.mediaPicker)
            }

            Divider()

            MenuRow(
                title: "Grid Size",
                systemImage: "square.grid.3x3.square",
                detail: session.isGauntletLadderMode
                    ? "Stage \(session.currentLadderStage) of \(GauntletLadderRules.stageCount)"
                    : session.difficultyDisplayValue,
                isEnabled: !session.isGauntletLadderMode
            ) {
                path.append(.gridSizePicker)
            }

            Divider()

            MenuRow(
                title: "Achievements",
                systemImage: "trophy.fill",
                detail: achievementsDetail,
                isLocked: isLocked(.achievementsArchive)
            ) {
                if isLocked(.achievementsArchive) {
                    paywallContext = .achievementsArchive
                } else {
                    path.append(.achievements)
                }
            }

            Divider()

            MenuRow(title: "Wall of Fame", systemImage: "photo.artframe", isLocked: isLocked(.wallOfFame)) {
                if isLocked(.wallOfFame) {
                    paywallContext = .wallOfFame
                } else {
                    path.append(.wallOfFame)
                }
            }

            if settings.challengeFriendsEnabled {
                Divider()

                MenuRow(title: "Challenge Nearby Friends", systemImage: "person.2.fill") {
                    path.append(.challengeHome)
                }
            }
        }
        .background(.quaternary, in: .rect(cornerRadius: 20))
        .padding(.horizontal)
        .paywallSheet(context: $paywallContext)
    }

    private var achievementsDetail: String {
        let visible = achievementsStore.visibleAchievements(challengeFriendsEnabled: settings.challengeFriendsEnabled)
        return "\(visible.count(where: \.isUnlocked))/\(visible.count)"
    }

    private func isLocked(_ feature: PremiumFeature) -> Bool {
        feature.isLocked(isPremiumUnlocked: store.isPremiumUnlocked)
    }
}
