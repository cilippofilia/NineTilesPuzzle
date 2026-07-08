//
//  ChallengeMultipeerSession.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import MultipeerConnectivity
import SwiftUI

/// Same-room Challenge Friends transport: advertise/browse/connect via Multipeer
/// Connectivity, then send the identical `FriendChallenge` payload the file transport uses
/// (`ChallengeFilePayload`/`ChallengeFileCoder`) as raw JSON `Data` instead of a file.
///
/// `MCSessionDelegate`/`MCNearbyServiceAdvertiserDelegate` callbacks arrive off the main
/// actor and aren't themselves `@MainActor`-isolated in the SDK — each conformance method
/// below is `nonisolated` and hops back to the main actor (mirroring `GameCenterService`'s
/// `authenticateHandler` pattern) before touching any published state.
@MainActor
@Observable
final class ChallengeMultipeerSession: NSObject {
    enum State: Equatable {
        case idle
        case advertising
        case connecting
        case connected(peerName: String)
        case failed(String)
    }

    /// Bare service name for `MCNearbyServiceAdvertiser`/`MCNearbyServiceBrowser` — must be
    /// ≤15 characters, lowercase letters/digits/hyphens only, no leading underscore or
    /// `._tcp` suffix. Distinct from the Info.plist `NSBonjourServices` entry, which needs
    /// the full `_ntp-challenge._tcp` form.
    static let serviceType = "ntp-challenge"

    private(set) var state: State = .idle
    private(set) var receivedChallenge: FriendChallenge?

    private let myPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?

    init(displayName: String) {
        myPeerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    func startAdvertising() {
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        state = .advertising
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        if state == .advertising { state = .idle }
    }

    /// Wrapped in `UIViewControllerRepresentable` by `NearbyChallengeView` — Apple's
    /// system-provided browse/invite/connect UI, used instead of a hand-rolled
    /// `MCNearbyServiceBrowser` delegate flow.
    func makeBrowserViewController() -> MCBrowserViewController {
        MCBrowserViewController(serviceType: Self.serviceType, session: session)
    }

    func send(_ challenge: FriendChallenge) throws {
        let data = try JSONEncoder().encode(challenge)
        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func disconnect() {
        session.disconnect()
        stopAdvertising()
        state = .idle
        receivedChallenge = nil
    }
}

extension ChallengeMultipeerSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.state = .connected(peerName: peerID.displayName)
            case .connecting:
                self.state = .connecting
            case .notConnected:
                if case .connected = self.state { self.state = .idle }
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let challenge = try? JSONDecoder().decode(FriendChallenge.self, from: data),
              challenge.formatVersion <= FriendChallenge.currentFormatVersion
        else { return }
        Task { @MainActor [weak self] in
            self?.receivedChallenge = challenge
        }
    }

    nonisolated func session(
        _ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID,
        at localURL: URL?, withError error: (any Error)?
    ) {}
}

extension ChallengeMultipeerSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        Task { @MainActor [weak self] in
            self?.state = .failed(error.localizedDescription)
        }
    }
}
