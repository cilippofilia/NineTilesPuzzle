//
//  ChallengeResultSendSheet.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/9/26.
//

import SwiftUI

/// Presented from the post-solve completion screen after finishing a *received* Challenge
/// Friends puzzle, letting the player send their result back to whoever challenged them —
/// the other half of the round trip `ChallengeSendSheet` starts. Much leaner than that sheet:
/// there's no image/mode/grid to package, just the tiny `ChallengeResult` reply.
struct ChallengeResultSendSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let challengeID: UUID
    let opponentName: String
    let moves: Int
    let time: TimeInterval

    @State private var nameInput = ""
    @State private var result: ChallengeResult?
    @State private var hasSent = false
    @State private var showNearby = false

    var body: some View {
        NavigationStack {
            Form {
                if settings.senderDisplayName.isEmpty {
                    Section {
                        TextField("Your Name", text: $nameInput)
                    } header: {
                        Text("Your Name")
                    } footer: {
                        Text("Shown to \(opponentName) when they see your result.")
                    }
                }

                Section {
                    LabeledContent("Your Moves", value: moves.formatted())
                    LabeledContent("Your Time", value: Duration.seconds(time).formatted(.time(pattern: .minuteSecond)))
                }

                if let result {
                    Section {
                        ShareLink(
                            item: ChallengeResultFilePayload(result: result),
                            preview: SharePreview("Nine Tiles Puzzle Result")
                        ) {
                            Label("Share Result", systemImage: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded { hasSent = true })

                        Button {
                            hasSent = true
                            showNearby = true
                        } label: {
                            Label("Send to Nearby Friend", systemImage: "wifi")
                        }
                    } footer: {
                        Text("Sends your result back to \(opponentName).")
                    }
                }
            }
            .navigationTitle("Send Result Back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showNearby) {
                if let result {
                    NearbyChallengeView(mode: .sendResult(result), senderName: result.responderName)
                }
            }
            .onAppear { prepareResultIfPossible() }
            .onChange(of: nameInput) { _, _ in prepareResultIfPossible() }
        }
    }

    private func prepareResultIfPossible() {
        guard result == nil else { return }
        let name = settings.senderDisplayName.isEmpty ? nameInput.trimmingCharacters(in: .whitespaces) : settings.senderDisplayName
        guard !name.isEmpty else { return }
        if settings.senderDisplayName.isEmpty {
            settings.setSenderDisplayName(name)
        }
        result = ChallengeResult(challengeID: challengeID, responderName: name, moves: moves, time: time)
    }
}

#Preview {
    ChallengeResultSendSheet(challengeID: UUID(), opponentName: "Alex", moves: 23, time: 45)
        .environment(SettingsStore())
}
