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

    @Binding var path: [GameRoute]

    var body: some View {
        VStack(spacing: 0) {
            if session.selectedGameMode != .zen {
                MenuStatsCardView()
                    .frame(height: 55)

                Divider()
            }

            MenuRow(title: "Game Mode", systemImage: "gamecontroller", detail: session.selectedGameMode.title) {
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
                detail: "\(achievementsStore.unlockedCount)/\(achievementsStore.achievements.count)"
            ) {
                path.append(.achievements)
            }

            Divider()

            MenuRow(title: "Wall of Fame", systemImage: "photo.artframe") {
                path.append(.wallOfFame)
            }

            Divider()

            MenuRow(title: "Challenge Nearby Friends", systemImage: "person.2.fill") {
                path.append(.challengeHome)
            }
        }
        .background(.quaternary, in: .rect(cornerRadius: 20))
        .padding(.horizontal)
    }
}

/// One tappable settings-style row: title/icon on the left, an optional detail value and
/// chevron on the right. `isEnabled` also hides the chevron, matching the Grid Size row's
/// look when grid size is locked by Gauntlet Ladder mode.
private struct MenuRow: View {
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
