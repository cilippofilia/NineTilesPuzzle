//
//  MenuView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI

enum GameRoute: Hashable {
    case game
    case gridSizePicker
    case achievements
    case gameModes
}

struct MenuView: View {
    @Environment(GameSession.self) private var session
    @Environment(AchievementsStore.self) private var achievementsStore
    @State private var path: [GameRoute] = []
    @State private var showStats = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Spacer()

                BrandMarkView()
                    .padding()

                VStack(spacing: 12) {
                    Button {
                        path.append(.gameModes)
                    } label: {
                        HStack {
                            LabeledContent("Game Mode", value: session.selectedGameMode.title)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .contentShape(.rect(cornerRadius: 20))
                    }
                    .foregroundStyle(.primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))

                    Button {
                        guard !session.isLadderMode else { return }
                        path.append(.gridSizePicker)
                    } label: {
                        HStack {
                            LabeledContent(
                                "Grid Size",
                                value: session.isLadderMode
                                    ? "Stage \(session.currentLadderStage) of \(GauntletLadderRules.stageCount)"
                                    : session.difficultyDisplayValue
                            )
                            if !session.isLadderMode {
                                Image(systemName: "chevron.forward")
                                    .imageScale(.small)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                    .foregroundStyle(session.isLadderMode ? .secondary : .primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))
                    .disabled(session.isLadderMode)

                    Button {
                        path.append(.achievements)
                    } label: {
                        HStack {
                            Label("Achievements", systemImage: "trophy.fill")
                            Spacer()
                            Text("\(achievementsStore.achievements.filter(\.isUnlocked).count)/\(achievementsStore.achievements.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .contentShape(.rect(cornerRadius: 20))
                    }
                    .foregroundStyle(.primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))

                    HStack(spacing: 12) {
                        Button {
                            showStats = true
                        } label: {
                            Label("Stats", systemImage: "chart.bar.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .contentShape(.rect(cornerRadius: 20))
                        }
                        .foregroundStyle(.primary)
                        .background(.quaternary, in: .rect(cornerRadius: 20))

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .contentShape(.rect(cornerRadius: 20))
                        }
                        .foregroundStyle(.primary)
                        .background(.quaternary, in: .rect(cornerRadius: 20))
                    }
                }
                .padding(.horizontal)

                Button {
                    session.tiles = []
                    session.isLoading = true
                    path.append(.game)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .contentShape(.rect(cornerRadius: 20))
                }
                .foregroundStyle(.white)
                .background(.blue, in: .rect(cornerRadius: 20))
                .padding()

                Spacer()
            }
            .sheet(isPresented: $showStats) {
                StatsView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .game:
                    PuzzleView()
                case .gridSizePicker:
                    GridSizePickerView()
                case .achievements:
                    AchievementsView()
                case .gameModes:
                    GameModeView()
                }
            }
        }
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    MenuView()
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings))
        .environment(stats)
        .environment(settings)
        .environment(achievements)
}
