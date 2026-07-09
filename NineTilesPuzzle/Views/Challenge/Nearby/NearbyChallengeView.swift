//
//  NearbyChallengeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

enum NearbyChallengeMode {
    /// Browsing for a nearby peer to send `FriendChallenge` to.
    case send(FriendChallenge)
    /// Browsing for a nearby peer to send a played challenge's `ChallengeResult` back to —
    /// the manual fallback for when the original invite didn't arrive over a still-open
    /// Nearby connection (e.g. it came in as a file).
    case sendResult(ChallengeResult)
    /// Advertising, waiting for a nearby peer to send a challenge.
    case receive
}

/// Same-room Challenge Friends UI — hosts both the sending role (browse for nearby peers, dial
/// the chosen one, then send once connected) and the receiving role (advertise, wait for a peer
/// to connect and send). Received challenges funnel through `onChallengeReceived`, handing the
/// still-open connection to the caller so both transports converge on one receiving UI
/// (`ChallengeInviteView`) while keeping the socket alive for an automatic result reply later.
///
/// For `.send`, the connection deliberately stays open after sending: the recipient is expected
/// to play the puzzle on the spot and the result comes back over this same socket (see
/// `GameSession.liveNearbySession`), so this screen waits in place and shows the outcome inline
/// instead of dismissing.
struct NearbyChallengeView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: NearbyChallengeMode
    let onChallengeReceived: (FriendChallenge, ChallengeNearbySession) -> Void
    let onResultReceived: (ChallengeResult) -> Void

    @State private var session: ChallengeNearbySession
    @State private var showBrowser = false
    @State private var didSend = false
    @State private var sendError: String?
    /// Set right before `onChallengeReceived` fires — the session's lifecycle now belongs to
    /// whoever received it (`GameSession`), so `onDisappear` must not disconnect it out from
    /// under them.
    @State private var didHandOffSession = false

    init(
        mode: NearbyChallengeMode,
        senderName: String,
        onChallengeReceived: @escaping (FriendChallenge, ChallengeNearbySession) -> Void = { _, _ in },
        onResultReceived: @escaping (ChallengeResult) -> Void = { _ in }
    ) {
        self.mode = mode
        self.onChallengeReceived = onChallengeReceived
        self.onResultReceived = onResultReceived
        _session = State(initialValue: ChallengeNearbySession(displayName: senderName))
    }

    var body: some View {
        NavigationStack {
            Group {
                if case .send(let challenge) = mode, let result = session.receivedResult {
                    resultOutcomeSection(challenge: challenge, result: result)
                } else {
                    waitingSection
                }
            }
            .navigationTitle("Nearby Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showBrowser) {
            NearbyPeerPickerView(session: session) { showBrowser = false }
        }
        .onChange(of: session.receivedChallenge) { _, challenge in
            guard let challenge else { return }
            didHandOffSession = true
            onChallengeReceived(challenge, session)
            dismiss()
        }
        .onChange(of: session.receivedResult) { _, result in
            guard let result else { return }
            onResultReceived(result)
            // `.send` shows the outcome inline instead of dismissing (see `body`); any other
            // mode (the manual `.sendResult` fallback dialing a `.receive` peer) is done here.
            if case .send = mode { return }
            dismiss()
        }
        .onDisappear {
            guard !didHandOffSession else { return }
            session.disconnect()
        }
    }

    private var waitingSection: some View {
        VStack(spacing: 32) {
            Spacer()

            statusIcon

            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.title2.bold())
                    .contentTransition(.numericText())
                Text(statusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let sendError {
                Label(sendError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            actionButton
                .padding(.horizontal)
        }
        .animation(.default, value: session.state)
    }

    /// Shown once the recipient's `ChallengeResult` lands back over the still-open connection —
    /// no separate share step, just the outcome right where the sender's still waiting.
    private func resultOutcomeSection(challenge: FriendChallenge, result: ChallengeResult) -> some View {
        let outcome = ChallengeStore.determineOutcome(
            yourMoves: challenge.senderMoves, yourTime: challenge.senderTime,
            creatorMoves: result.moves, creatorTime: result.time
        )
        return VStack(spacing: 16) {
            Spacer()
            ChallengeOutcomeView(
                outcome: outcome,
                opponentName: result.responderName,
                yourMoves: challenge.senderMoves,
                yourTime: challenge.senderTime,
                opponentMoves: result.moves,
                opponentTime: result.time
            )
            .padding(.horizontal)
            Spacer()
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch mode {
        case .send, .sendResult:
            if isConnected {
                if !didSend {
                    Button(sendButtonTitle, action: sendPayload)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            } else if isBusy {
                cancelButton
            } else {
                Button("Find Nearby Player") {
                    session.startBrowsing()
                    showBrowser = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        case .receive:
            if isAdvertising {
                cancelButton
            } else {
                Button("Start Waiting") {
                    session.startAdvertising()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Lets the user back out of an in-progress search/wait and return to the idle state, so
    /// they can start it again (e.g. after realizing their friend isn't ready yet) instead of
    /// being stuck watching a spinner with no way out short of closing the sheet.
    private var cancelButton: some View {
        Button("Cancel") {
            session.disconnect()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private func sendPayload() {
        do {
            switch mode {
            case .send(let challenge):
                try session.send(challenge)
            case .sendResult(let result):
                try session.send(result)
            case .receive:
                return
            }
            didSend = true
        } catch {
            sendError = error.localizedDescription
        }
    }

    private var sendButtonTitle: String {
        if case .sendResult = mode { return "Send Result" }
        return "Send Challenge"
    }

    private var sentTitle: String {
        if case .sendResult = mode { return "Result Sent!" }
        return "Challenge Sent!"
    }

    private var isReceiving: Bool {
        if case .receive = mode { return true }
        return false
    }

    private var isConnected: Bool {
        if case .connected = session.state { return true }
        return false
    }

    private var isAdvertising: Bool {
        if case .advertising = session.state { return true }
        return false
    }

    /// Whether the peer discovery/connect handshake is mid-flight — used to keep the searching
    /// ring animating and the primary button disabled so a second tap can't race it.
    private var isBusy: Bool {
        switch session.state {
        case .browsing, .connecting: true
        default: false
        }
    }

    private var statusTint: Color {
        switch session.state {
        case .idle: .gray
        case .advertising, .browsing, .connecting: .blue
        case .connected: didSend ? .green : .blue
        case .failed: .red
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusTint.opacity(0.15))
                .frame(width: 140, height: 140)

            switch session.state {
            case .idle:
                Image(systemName: isReceiving ? "antenna.radiowaves.left.and.right" : "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(statusTint)
            case .advertising, .browsing:
                Image(systemName: "wifi")
                    .font(.system(size: 48))
                    .symbolEffect(.variableColor.iterative.reversing)
                    .foregroundStyle(statusTint)
            case .connecting:
                ProgressView()
                    .controlSize(.large)
            case .connected:
                Image(systemName: didSend ? "checkmark.circle.fill" : "person.crop.circle.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(statusTint)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(statusTint)
            }
        }
    }

    private var statusTitle: String {
        switch session.state {
        case .idle:
            isReceiving ? "Ready to Wait" : "Ready to Send"
        case .advertising:
            "Waiting for a Friend…"
        case .browsing:
            "Looking for Players…"
        case .connecting:
            "Connecting…"
        case .connected(let name):
            isReceiving ? "Connected to \(name)" : (didSend ? sentTitle : "Connected to \(name)")
        case .failed:
            "Connection Failed"
        }
    }

    private var statusSubtitle: String {
        switch session.state {
        case .idle:
            isReceiving
                ? "Tap Start Waiting so a nearby friend can send you a challenge."
                : "Tap Find Nearby Player to look for a friend waiting nearby."
        case .advertising:
            "Keep this screen open — your friend just needs to send it from their device."
        case .browsing:
            "Make sure your friend has tapped “Start Waiting” nearby."
        case .connecting:
            "Hang tight, almost there."
        case .connected:
            if isReceiving {
                "Waiting for their challenge to arrive…"
            } else if !didSend {
                "Tap \(sendButtonTitle) to deliver it."
            } else if case .send = mode {
                "Keep this open — you'll see the result the instant they finish playing."
            } else {
                "They'll see it next time they open Nine Tiles."
            }
        case .failed(let message):
            message
        }
    }
}
