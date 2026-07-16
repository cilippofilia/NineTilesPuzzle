//
//  ChallengeFileOpeningModifier.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI

/// Owns everything involved in receiving a `.ntpchallenge` file: decoding it when the app is
/// opened via a Messages attachment tap, AirDrop accept, or Files "Open in Nine Tiles Puzzle",
/// then showing the invite (or a result alert for a reply), or a failure alert if it couldn't
/// be opened at all. `onAcceptChallenge` is left to the caller since accepting still needs
/// menu-specific navigation (e.g. popping an active game before entering the new one).
private struct ChallengeFileOpening: ViewModifier {
    @Environment(ChallengeStore.self) private var challengeStore
    @Environment(SettingsStore.self) private var settings

    @State private var incomingChallenge: FriendChallenge?
    /// Set when a `ChallengeResult` reply arrives for a challenge this device originally sent —
    /// drives a one-shot alert since there's no invite to accept, just history to update.
    @State private var receivedResultRecord: ChallengeRecord?
    /// Set when a tapped `.ntpchallenge` file fails to open, so the user sees *something*
    /// instead of the tap silently doing nothing.
    @State private var challengeOpenFailure: ChallengeFileCoder.DecodeFailure?
    /// Set when a `.ntpchallenge` file is opened while the feature is turned off in Settings.
    @State private var showFeatureDisabledAlert = false

    let onAcceptChallenge: (FriendChallenge) -> Void

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                guard url.isFileURL else { return }
                guard settings.challengeFriendsEnabled else {
                    showFeatureDisabledAlert = true
                    return
                }
                switch ChallengeFileCoder.decode(fileAt: url) {
                case .success(let payload):
                    switch payload {
                    case .invite(let challenge):
                        challengeStore.registerReceived(challenge, transport: .file)
                        incomingChallenge = challenge
                    case .result(let result):
                        receivedResultRecord = challengeStore.recordOpponentResult(result)
                    }
                case .failure(let failure):
                    challengeOpenFailure = failure
                }
            }
            .fullScreenCover(item: $incomingChallenge) { challenge in
                ChallengeInviteView(
                    challenge: challenge,
                    onAccept: {
                        incomingChallenge = nil
                        onAcceptChallenge(challenge)
                    },
                    onDecline: { incomingChallenge = nil }
                )
            }
            .alert(
                receivedResultRecord?.resultAlertTitle ?? "",
                isPresented: Binding(
                    get: { receivedResultRecord != nil },
                    set: { if !$0 { receivedResultRecord = nil } }
                )
            ) {
                Button("OK") { receivedResultRecord = nil }
            } message: {
                Text(receivedResultRecord?.resultAlertMessage ?? "")
            }
            .alert(
                "Couldn't Open Challenge",
                isPresented: Binding(
                    get: { challengeOpenFailure != nil },
                    set: { if !$0 { challengeOpenFailure = nil } }
                )
            ) {
                Button("OK") { challengeOpenFailure = nil }
            } message: {
                Text(challengeOpenFailureMessage)
            }
            .alert("Challenge Friends is Off", isPresented: $showFeatureDisabledAlert) {
                Button("OK") { }
            } message: {
                Text("Turn on Challenge Friends in Settings to open shared challenges.")
            }
    }

    private var challengeOpenFailureMessage: String {
        switch challengeOpenFailure {
        case .unreadable:
            "This challenge file couldn't be read. If it just arrived, it may still be downloading — wait a moment and try opening it again."
        case .corrupted:
            "This challenge file appears to be damaged or isn't a Nine Tiles Puzzle challenge."
        case .unsupportedFormatVersion:
            "This challenge was created with a newer version of Nine Tiles Puzzle. Update the app to open it."
        case nil:
            ""
        }
    }
}

extension View {
    /// Attaches challenge-file receiving (invite, result, and failure handling) to this view.
    /// `onAcceptChallenge` fires once the user accepts an invite that arrived as a file.
    func handlingOpenedChallengeFiles(onAcceptChallenge: @escaping (FriendChallenge) -> Void) -> some View {
        modifier(ChallengeFileOpening(onAcceptChallenge: onAcceptChallenge))
    }
}
