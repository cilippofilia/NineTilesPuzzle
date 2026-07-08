//
//  NearbyChallengeView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import MultipeerConnectivity
import SwiftUI

enum NearbyChallengeMode {
    /// Browsing for a nearby peer to send `FriendChallenge` to.
    case send(FriendChallenge)
    /// Advertising, waiting for a nearby peer to send a challenge.
    case receive
}

/// Same-room Challenge Friends UI — hosts both the sending role (browse via
/// `MCBrowserViewController`, then send once connected) and the receiving role (advertise,
/// wait for a peer to connect and send). Received challenges funnel through the same
/// `onChallengeReceived` callback the file-open path uses, so both transports converge on
/// one receiving UI (`ChallengeInviteView`).
struct NearbyChallengeView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: NearbyChallengeMode
    let onChallengeReceived: (FriendChallenge) -> Void

    @State private var multipeer: ChallengeMultipeerSession
    @State private var showBrowser = false
    @State private var didSend = false
    @State private var sendError: String?

    init(mode: NearbyChallengeMode, senderName: String, onChallengeReceived: @escaping (FriendChallenge) -> Void) {
        self.mode = mode
        self.onChallengeReceived = onChallengeReceived
        _multipeer = State(initialValue: ChallengeMultipeerSession(displayName: senderName))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                statusView

                switch mode {
                case .send:
                    Button("Find Nearby Player") { showBrowser = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(isConnected)

                    if isConnected, !didSend {
                        Button("Send Challenge", action: sendChallenge)
                            .buttonStyle(.borderedProminent)
                    }
                case .receive:
                    Button(isAdvertising ? "Waiting for a Challenge…" : "Start Waiting") {
                        multipeer.startAdvertising()
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
            MultipeerBrowserRepresentable(session: multipeer) { showBrowser = false }
        }
        .onChange(of: multipeer.receivedChallenge) { _, challenge in
            guard let challenge else { return }
            onChallengeReceived(challenge)
            dismiss()
        }
        .onDisappear { multipeer.disconnect() }
    }

    private func sendChallenge() {
        guard case .send(let challenge) = mode else { return }
        do {
            try multipeer.send(challenge)
            didSend = true
        } catch {
            sendError = error.localizedDescription
        }
    }

    private var isConnected: Bool {
        if case .connected = multipeer.state { return true }
        return false
    }

    private var isAdvertising: Bool {
        if case .advertising = multipeer.state { return true }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        switch multipeer.state {
        case .idle:
            Text("Not connected").foregroundStyle(.secondary)
        case .advertising:
            Label("Waiting for a nearby friend…", systemImage: "wifi").foregroundStyle(.secondary)
        case .connecting:
            ProgressView("Connecting…")
        case .connected(let name):
            Label("Connected to \(name)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        }
    }
}

private struct MultipeerBrowserRepresentable: UIViewControllerRepresentable {
    let session: ChallengeMultipeerSession
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MCBrowserViewController {
        let controller = session.makeBrowserViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MCBrowserViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MCBrowserViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        nonisolated func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
            Task { @MainActor in
                browserViewController.dismiss(animated: true)
                self.onFinish()
            }
        }

        nonisolated func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
            Task { @MainActor in
                browserViewController.dismiss(animated: true)
                self.onFinish()
            }
        }
    }
}
