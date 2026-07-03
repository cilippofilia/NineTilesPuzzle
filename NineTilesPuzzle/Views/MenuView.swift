//
//  MenuView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI
import UIKit

enum GameRoute: Hashable {
    case game
    case gridSizePicker
    case achievements
    case wallOfFame
    case gameModes
    case mediaPicker
}

struct MenuView: View {
    @Environment(GameSession.self) private var session
    @Environment(AchievementsStore.self) private var achievementsStore
    @Environment(DailyChallengeStore.self) private var dailyChallengeStore
    @Environment(\.openURL) private var openURL
    @State private var path: [GameRoute] = []
    @State private var showSettings = false
    @State private var showTipsAlert = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Spacer()

                BrandMarkView()
                    .padding()

                DailyChallengeCardView {
                    session.enterDailyMode()
                    session.tiles = []
                    session.isLoading = true
                    path.append(.game)
                }
                .padding([.horizontal, .bottom])

                VStack(spacing: 12) {
                    MenuStatsCardView()
                        .frame(height: 55)

                    Button {
                        path.append(.gameModes)
                    } label: {
                        HStack {
                            Label("Game Mode", systemImage: "gamecontroller")
                            Spacer()
                            Text(session.selectedGameMode.title)
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

                    Button {
                        path.append(.mediaPicker)
                    } label: {
                        HStack {
                            Label("Media", systemImage: "photo.tv")
                            Spacer()
                            Text(session.mediaSourceType.label)
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

                    Button {
                        guard !session.isGauntletLadderMode else { return }
                        path.append(.gridSizePicker)
                    } label: {
                        HStack {
                            Label("Grid Size", systemImage: "square.grid.3x3.square")
                            Spacer()
                            Text(session.isGauntletLadderMode
                                 ? "Stage \(session.currentLadderStage) of \(GauntletLadderRules.stageCount)"
                                 : session.difficultyDisplayValue)
                                .foregroundStyle(.secondary)
                            if !session.isGauntletLadderMode {
                                Image(systemName: "chevron.forward")
                                    .imageScale(.small)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .contentShape(.rect(cornerRadius: 20))
                    }
                    .foregroundStyle(session.isGauntletLadderMode ? .secondary : .primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))
                    .disabled(session.isGauntletLadderMode)

                    Button {
                        path.append(.achievements)
                    } label: {
                        HStack {
                            Label("Achievements", systemImage: "trophy.fill")
                            Spacer()
                            Text("\(achievementsStore.unlockedCount)/\(achievementsStore.achievements.count)")
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

                    Button {
                        path.append(.wallOfFame)
                    } label: {
                        HStack {
                            Label("Wall of Fame", systemImage: "photo.artframe")
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .contentShape(.rect(cornerRadius: 20))
                    }
                    .foregroundStyle(.primary)
                    .background(.quaternary, in: .rect(cornerRadius: 20))

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
                case .wallOfFame:
                    WallOfFameView()
                case .gameModes:
                    GameModeView()
                case .mediaPicker:
                    MediaSourcePickerView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape.fill") {
                        showSettings = true
                    }
                    .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tips", systemImage: "lightbulb.max") {
                        showTipsAlert = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .alert("Quick Tip", isPresented: $showTipsAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Got It", role: .cancel) { }
            } message: {
                Text("For a curated experience with your own photos, create a dedicated album in the Photos app with only the images you'd like to use as puzzles, then grant Nine Tiles access to that album only.")
            }
        }
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    let daily = DailyChallengeStore()
    MenuView()
        .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: daily))
        .environment(stats)
        .environment(settings)
        .environment(achievements)
        .environment(daily)
}
