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
    /// Advertising, waiting for a nearby peer to send a challenge.
    case receive
}

/// Same-room Challenge Friends UI — hosts both the sending role (browse for nearby peers, dial
/// the chosen one, then send once connected) and the receiving role (advertise, wait for a peer
/// to connect and send). Received challenges funnel through the same `onChallengeReceived`
/// callback the file-open path uses, so both transports converge on one receiving UI
/// (`ChallengeInviteView`).
struct NearbyChallengeView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: NearbyChallengeMode
    let onChallengeReceived: (FriendChallenge) -> Void

    @State private var session: ChallengeNearbySession
    @State private var showBrowser = false
    @State private var didSend = false
    @State private var sendError: String?

    init(mode: NearbyChallengeMode, senderName: String, onChallengeReceived: @escaping (FriendChallenge) -> Void) {
        self.mode = mode
        self.onChallengeReceived = onChallengeReceived
        _session = State(initialValue: ChallengeNearbySession(displayName: senderName))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                statusView

                switch mode {
                case .send:
                    Button("Find Nearby Player") {
                        session.startBrowsing()
                        showBrowser = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnected)

                    if isConnected, !didSend {
                        Button("Send Challenge", action: sendChallenge)
                            .buttonStyle(.borderedProminent)
                    }
                case .receive:
                    Button(isAdvertising ? "Waiting for a Challenge…" : "Start Waiting") {
                        session.startAdvertising()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAdvertising)
                }

                if didSend {
                    Label("Challenge Sent!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let sendError {
                    Text(sendError).foregroundStyle(.red).font(.caption)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Nearby Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showBrowser) {
            NearbyPeerPickerView(session: session) { showBrowser = false }
        }
        .onChange(of: session.receivedChallenge) { _, challenge in
            guard let challenge else { return }
            onChallengeReceived(challenge)
            dismiss()
        }
        .onDisappear { session.disconnect() }
    }

    private func sendChallenge() {
        guard case .send(let challenge) = mode else { return }
        do {
            try session.send(challenge)
            didSend = true
        } catch {
            sendError = error.localizedDescription
        }
    }

    private var isConnected: Bool {
        if case .connected = session.state { return true }
        return false
    }

    private var isAdvertising: Bool {
        if case .advertising = session.state { return true }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        switch session.state {
        case .idle:
            Text("Not connected").foregroundStyle(.secondary)
        case .advertising:
            Label("Waiting for a nearby friend…", systemImage: "wifi").foregroundStyle(.secondary)
        case .browsing:
            Label("Looking for nearby players…", systemImage: "wifi").foregroundStyle(.secondary)
        case .connecting:
            ProgressView("Connecting…")
        case .connected(let name):
            Label("Connected to \(name)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        }
    }
}

/// Native replacement for Multipeer's `MCBrowserViewController`: lists the peers the
/// `NWBrowser` has found and dials the one the user taps.
private struct NearbyPeerPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let session: ChallengeNearbySession
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if session.discoveredPeers.isEmpty {
                    ContentUnavailableView {
                        Label("Looking for Players", systemImage: "wifi")
                    } description: {
                        Text("Make sure your friend has tapped “Start Waiting” nearby.")
                    }
                } else {
                    List(session.discoveredPeers) { peer in
                        Button {
                            session.invite(peer)
                            onFinish()
                            dismiss()
                        } label: {
                            Label(peer.name, systemImage: "person.crop.circle")
                        }
                    }
                }
            }
            .navigationTitle("Nearby Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        session.stopBrowsing()
                        onFinish()
                        dismiss()
                    }
                }
            }
        }
    }
}
