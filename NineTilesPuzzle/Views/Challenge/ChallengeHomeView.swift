//
//  ChallengeHomeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// The dedicated Challenge Friends screen: receive a nearby challenge, plus history of every
/// challenge sent or received (including unplayed invites, reopenable from here without
/// needing the original file/link again). Sending a challenge happens from a game's completion
/// screen instead, using whatever was just played.
struct ChallengeHomeView: View {
    /// How many recent records show inline before handing off to the full, scrollable list.
    static let historyPreviewCount = 10

    @Environment(GameSession.self) private var session
    @Environment(ChallengeStore.self) private var challengeStore
    @Environment(SettingsStore.self) private var settings

    @State private var incomingChallenge: FriendChallenge?
    /// The still-open connection the current `incomingChallenge` arrived over, if it came in
    /// live via Nearby rather than as a file or a reopened history entry — handed to
    /// `GameSession.enterChallengeMode(with:nearbySession:)` on accept so the result can be
    /// sent back automatically once the puzzle is solved.
    @State private var incomingNearbySession: ChallengeNearbySession?
    @State private var showNearbyReceive = false
    @State private var showClearHistoryAlert = false
    /// Set when a `ChallengeResult` reply arrives over Nearby for a challenge this device
    /// originally sent — mirrors `MenuView`'s file-transport handling of the same event.
    @State private var receivedResultRecord: ChallengeRecord?

    /// Enters challenge mode with the reopened challenge and pushes the puzzle. `nearbySession`
    /// is non-nil only when the challenge just arrived live over Nearby.
    let onAcceptChallenge: (FriendChallenge, ChallengeNearbySession?) -> Void

    var body: some View {
        List {
            Section {
                Button {
                    showNearbyReceive = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "wifi")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.15), in: .circle)

                        Text("Wait for a Nearby Challenge")
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.forward")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
            } footer: {
                Text("A friend in the same room can send you a challenge directly, no link needed.")
            }
            .buttonStyle(.plain)

            Section("History") {
                if challengeStore.records.isEmpty {
                    ContentUnavailableView {
                        Label("No Challenges Yet", systemImage: "person.2.slash")
                    } description: {
                        Text("Challenges you send or receive will show up here.")
                    }
                } else {
                    ForEach(challengeStore.records.prefix(Self.historyPreviewCount)) { record in
                        ChallengeHistoryRow(record: record)
                            .contentShape(.rect)
                            .onTapGesture { openIfPending(record) }
                    }
                    if challengeStore.records.count > Self.historyPreviewCount {
                        NavigationLink(value: GameRoute.challengeHistory) {
                            Text("See All \(challengeStore.records.count) Challenges")
                        }
                    }
                }
            }

            Section {
                if !challengeStore.records.isEmpty {
                    Button("Clear History", systemImage: "trash", role: .destructive) {
                        showClearHistoryAlert = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Challenge Friends")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Challenge History?", isPresented: $showClearHistoryAlert) {
            Button("Clear", role: .destructive) { challengeStore.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every sent and received challenge from your history. Challenges already delivered to friends aren't affected.")
        }
        .fullScreenCover(item: $incomingChallenge) { challenge in
            ChallengeInviteView(
                challenge: challenge,
                onAccept: {
                    let challenge = incomingChallenge
                    let nearbySession = incomingNearbySession
                    incomingChallenge = nil
                    incomingNearbySession = nil
                    if let challenge { onAcceptChallenge(challenge, nearbySession) }
                },
                onDecline: {
                    incomingChallenge = nil
                    incomingNearbySession?.disconnect()
                    incomingNearbySession = nil
                }
            )
        }
        .sheet(isPresented: $showNearbyReceive) {
            NearbyChallengeView(
                mode: .receive,
                senderName: settings.senderDisplayName.isEmpty ? "A Player" : settings.senderDisplayName,
                onChallengeReceived: { challenge, nearbySession in
                    challengeStore.registerReceived(challenge, transport: .nearby)
                    incomingChallenge = challenge
                    incomingNearbySession = nearbySession
                },
                onResultReceived: { result in
                    receivedResultRecord = challengeStore.recordOpponentResult(result)
                }
            )
        }
        .alert(
            resultAlertTitle,
            isPresented: Binding(
                get: { receivedResultRecord != nil },
                set: { if !$0 { receivedResultRecord = nil } }
            )
        ) {
            Button("OK") { receivedResultRecord = nil }
        } message: {
            Text(resultAlertMessage)
        }
    }

    private func openIfPending(_ record: ChallengeRecord) {
        guard record.direction == .received, record.outcome == nil,
              let challenge = challengeStore.pendingChallenge(for: record)
        else { return }
        incomingChallenge = challenge
    }

    private var resultAlertTitle: String { receivedResultRecord?.resultAlertTitle ?? "" }
    private var resultAlertMessage: String { receivedResultRecord?.resultAlertMessage ?? "" }
}

struct ChallengeHistoryRow: View {
    @Environment(ChallengeStore.self) private var challengeStore

    let record: ChallengeRecord

    private var directionIcon: String {
        record.direction == .sent ? "paperplane.fill" : "tray.and.arrow.down.fill"
    }

    private var directionTint: Color {
        record.direction == .sent ? .blue : .purple
    }

    private var opponentLabel: String {
        record.direction == .sent
            ? "To \(record.opponentName)"
            : "From \(record.opponentName)"
    }

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
        case nil: record.direction == .received ? .blue : .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(opponentLabel)
                    .font(.body.weight(.medium))
                Text("\(record.gameMode.title) · \(record.gridSize)×\(record.gridSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(outcomeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(outcomeTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(outcomeTint.opacity(0.15), in: .capsule)

                Text(record.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// The challenge's puzzle image at row scale, with a small direction badge overlaid so
    /// sent vs. received stays legible even once the thumbnail has loaded in.
    private var thumbnail: some View {
        ZStack {
            if let image = challengeStore.image(for: record.id) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                directionTint.opacity(0.15)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: directionIcon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(directionTint, in: .circle)
                .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
                .offset(x: 4, y: 4)
        }
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
        ChallengeHomeView(onAcceptChallenge: { _, _ in })
            .environment(GameSession(
                statsStore: stats, achievementsStore: achievements, settingsStore: settings,
                dailyChallengeStore: daily, powerUpStore: powerUps, challengeStore: challenges
            ))
            .environment(challenges)
            .environment(settings)
    }
}
