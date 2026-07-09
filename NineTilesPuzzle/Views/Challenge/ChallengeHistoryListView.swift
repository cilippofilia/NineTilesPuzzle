//
//  ChallengeHistoryListView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/9/26.
//

import SwiftUI

/// The full, scrollable Challenge Friends history — reached from `ChallengeHomeView`'s
/// "See All" link once there are more records than fit in its inline preview.
struct ChallengeHistoryListView: View {
    @Environment(ChallengeStore.self) private var challengeStore

    @State private var incomingChallenge: FriendChallenge?

    /// Enters challenge mode with a reopened, unplayed received challenge.
    let onAcceptChallenge: (FriendChallenge) -> Void

    var body: some View {
        List(challengeStore.records) { record in
            ChallengeHistoryRow(record: record)
                .contentShape(.rect)
                .onTapGesture { openIfPending(record) }
        }
        .navigationTitle("Challenge History")
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
    }

    private func openIfPending(_ record: ChallengeRecord) {
        guard record.direction == .received, record.outcome == nil,
              let challenge = challengeStore.pendingChallenge(for: record)
        else { return }
        incomingChallenge = challenge
    }
}

#Preview {
    let challenges = ChallengeStore()

    NavigationStack {
        ChallengeHistoryListView(onAcceptChallenge: { _ in })
            .environment(challenges)
    }
}
