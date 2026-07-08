//
//  ChallengeSendSheet.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// Presented from the post-solve completion screen (or a fresh challenge started from
/// `ChallengeHomeView`) to package up a just-played game as a `FriendChallenge` and send it.
/// Prompts for a display name the first time it's used, then hands off to the standard share
/// sheet via `ChallengeFilePayload`'s file-based `Transferable`.
struct ChallengeSendSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ChallengeStore.self) private var challengeStore
    @Environment(\.dismiss) private var dismiss

    let gameMode: GameMode
    let gridSize: Int
    let image: CGImage
    let moves: Int
    let time: TimeInterval
    /// Set when this send is a reply to a received challenge — pre-fills who it's for.
    var opponentLabel: String?
    var parentChallengeID: UUID?

    @State private var nameInput = ""
    @State private var recipientInput = ""
    @State private var challenge: FriendChallenge?
    @State private var hasSent = false
    @State private var showNearby = false

    private var isRechallenge: Bool { opponentLabel != nil }

    var body: some View {
        NavigationStack {
            Form {
                if settings.senderDisplayName.isEmpty {
                    Section {
                        TextField("Your Name", text: $nameInput)
                    } header: {
                        Text("Your Name")
                    } footer: {
                        Text("Shown to the friend you're challenging.")
                    }
                }

                Section {
                    LabeledContent("Mode", value: gameMode.title)
                    LabeledContent("Grid", value: "\(gridSize)×\(gridSize)")
                    LabeledContent("Your Moves", value: moves.formatted())
                    LabeledContent("Your Time", value: Duration.seconds(time).formatted(.time(pattern: .minuteSecond)))
                }

                if !isRechallenge {
                    Section {
                        TextField("Friend's Name (optional)", text: $recipientInput)
                    } footer: {
                        Text("Just a label for your own history — it isn't sent anywhere.")
                    }
                }

                if let challenge {
                    Section {
                        ShareLink(
                            item: ChallengeFilePayload(challenge: challenge),
                            preview: SharePreview("Nine Tiles Puzzle Challenge")
                        ) {
                            Label("Share Challenge", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showNearby = true
                        } label: {
                            Label("Send to Nearby Friend", systemImage: "wifi")
                        }
                    }
                }
            }
            .navigationTitle(isRechallenge ? "Challenge Them Back" : "Challenge a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showNearby) {
                if let challenge {
                    NearbyChallengeView(
                        mode: .send(challenge),
                        senderName: challenge.senderName,
                        onChallengeReceived: { _ in }
                    )
                }
            }
            .onAppear { prepareChallengeIfPossible() }
            .onChange(of: nameInput) { _, _ in prepareChallengeIfPossible() }
        }
    }

    private func prepareChallengeIfPossible() {
        guard challenge == nil else { return }
        let name = settings.senderDisplayName.isEmpty ? nameInput.trimmingCharacters(in: .whitespaces) : settings.senderDisplayName
        guard !name.isEmpty else { return }
        if settings.senderDisplayName.isEmpty {
            settings.setSenderDisplayName(name)
        }
        guard let built = ChallengeComposer.makeChallenge(
            senderName: name,
            gameMode: gameMode,
            gridSize: gridSize,
            image: image,
            senderMoves: moves,
            senderTime: time,
            parentChallengeID: parentChallengeID
        ) else { return }
        challenge = built
        registerSentIfNeeded(built)
    }

    private func registerSentIfNeeded(_ challenge: FriendChallenge) {
        guard !hasSent else { return }
        hasSent = true
        let label = opponentLabel ?? {
            let trimmed = recipientInput.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "A friend" : trimmed
        }()
        challengeStore.registerSent(challenge, opponentLabel: label, transport: .file)
    }
}

#Preview {
    let image: CGImage = {
        let context = CGContext(
            data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        return context.makeImage()!
    }()

    ChallengeSendSheet(
        gameMode: .swap, gridSize: 4, image: image, moves: 23, time: 45
    )
    .environment(SettingsStore())
    .environment(ChallengeStore())
}
