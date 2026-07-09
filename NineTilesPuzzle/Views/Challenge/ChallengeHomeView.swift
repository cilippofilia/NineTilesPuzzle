//
//  ChallengeHomeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// The dedicated Challenge Friends screen: a shortcut to start a fresh challengeable puzzle,
/// plus history of every challenge sent or received (including unplayed invites, reopenable
/// from here without needing the original file/link again).
struct ChallengeHomeView: View {
    @Environment(GameSession.self) private var session
    @Environment(ChallengeStore.self) private var challengeStore
    @Environment(SettingsStore.self) private var settings

    @State private var selectedMode: GameMode
    @State private var selectedGridSize: Int
    @State private var incomingChallenge: FriendChallenge?
    @State private var showNearbyReceive = false

    /// Starts a fresh ordinary game configured with the picker's mode/grid size — sending a
    /// challenge happens afterward, from the completion screen, like any other finished game.
    let onPlay: () -> Void
    /// Enters challenge mode with the reopened challenge and pushes the puzzle.
    let onAcceptChallenge: (FriendChallenge) -> Void

    init(onPlay: @escaping () -> Void, onAcceptChallenge: @escaping (FriendChallenge) -> Void) {
        self.onPlay = onPlay
        self.onAcceptChallenge = onAcceptChallenge
        _selectedMode = State(initialValue: ChallengeStore.eligibleGameModes.first ?? .swap)
        _selectedGridSize = State(initialValue: 4)
    }

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(ChallengeStore.eligibleGameModes) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("Grid Size", selection: $selectedGridSize) {
                    ForEach(3...8, id: \.self) { size in
                        Text("\(size)×\(size)").tag(size)
                    }
                }
                Button("Start Puzzle") {
                    session.setGameMode(selectedMode)
                    session.setGridSize(selectedGridSize)
                    onPlay()
                }
            } header: {
                Text("Start a New Challenge")
            } footer: {
                Text("Finish the puzzle, then send it to a friend from the completion screen.")
            }

            Section {
                Button("Wait for a Nearby Challenge") {
                    showNearbyReceive = true
                }
            } footer: {
                Text("A friend in the same room can send you a challenge directly, no link needed.")
            }

            if !challengeStore.records.isEmpty {
                Section("History") {
                    ForEach(challengeStore.records) { record in
                        ChallengeHistoryRow(record: record)
                            .contentShape(.rect)
                            .onTapGesture { openIfPending(record) }
                    }
                }
            }
        }
        .navigationTitle("Challenge Friends")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $incomingChallenge) { challenge in
            ChallengeInviteView(
                challenge: challenge,
                onAccept: {
                    let challenge = incomingChallenge
                    incomingChallenge = nil
                    if let challenge { onAcceptChallenge(challenge) }
                },
                onDecline: { incomingChallenge = nil }
            )
        }
        .sheet(isPresented: $showNearbyReceive) {
            NearbyChallengeView(
                mode: .receive,
                senderName: settings.senderDisplayName.isEmpty ? "A Player" : settings.senderDisplayName,
                onChallengeReceived: { challenge in
                    challengeStore.registerReceived(challenge, transport: .nearby)
                    incomingChallenge = challenge
                }
            )
        }
    }

    private func openIfPending(_ record: ChallengeRecord) {
        guard record.direction == .received, record.outcome == nil,
              let challenge = challengeStore.pendingChallenge(for: record)
        else { return }
        incomingChallenge = challenge
    }
}

private struct ChallengeHistoryRow: View {
    let record: ChallengeRecord

    private var outcomeLabel: String {
        switch record.outcome {
        case .won: "Won"
        case .lost: "Lost"
        case .tied: "Tied"
        case nil: record.direction == .received ? "Unplayed" : "Sent"
        }
    }

    private var outcomeTint: Color {
        switch record.outcome {
        case .won: .green
        case .lost: .red
        case .tied: .orange
        case nil: .secondary
        }
    }

    var body: some View {
        HStack {
            Image(systemName: record.direction == .sent ? "paperplane.fill" : "tray.and.arrow.down.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.opponentName)
                    .font(.body)
                Text("\(record.gameMode.title) · \(record.gridSize)×\(record.gridSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(outcomeLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(outcomeTint)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    let daily = DailyChallengeStore()
    let powerUps = PowerUpStore()
    let challenges = ChallengeStore()

    NavigationStack {
        ChallengeHomeView(onPlay: {}, onAcceptChallenge: { _ in })
            .environment(GameSession(
                statsStore: stats, achievementsStore: achievements, settingsStore: settings,
                dailyChallengeStore: daily, powerUpStore: powerUps, challengeStore: challenges
            ))
            .environment(challenges)
            .environment(settings)
    }
}
