//
//  ChallengeNearbySession.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import Network
import SwiftUI

/// Same-room Challenge Friends transport built on `Network.framework` (the modern replacement
/// for the now-deprecated Multipeer Connectivity). The receiver advertises an `NWListener`
/// Bonjour service (`_ntp-challenge._tcp`) and waits for an incoming `NWConnection`; the
/// sender discovers peers with an `NWBrowser` and dials the one the user taps. Both roles then
/// exchange the same `FriendChallenge` payload the file transport uses, as length-prefixed
/// JSON over the connection.
///
/// The Bonjour service type and `NSLocalNetworkUsageDescription` string live in `Info.plist`
/// under `NSBonjourServices` — unchanged from the Multipeer version, since Bonjour advertising
/// requires the same declarations either way.
///
/// `NWListener`/`NWBrowser`/`NWConnection` callbacks arrive on a background `DispatchQueue`, so
/// every handler hops back to the main actor before touching published state; the receive-loop
/// helpers are `nonisolated` because they only touch the connection they're handed.
@MainActor
@Observable
final class ChallengeNearbySession {
    enum State: Equatable {
        case idle
        case advertising
        case browsing
        case connecting
        case connected(peerName: String)
        case failed(String)
    }

    /// A nearby device found while browsing, surfaced to the peer-picker UI.
    struct DiscoveredPeer: Identifiable, Equatable {
        let id: String
        let name: String
        let endpoint: NWEndpoint
    }

    enum NearbyError: LocalizedError {
        case notConnected

        var errorDescription: String? {
            switch self {
            case .notConnected: "Not connected to a nearby player."
            }
        }
    }

    /// Full Bonjour service type. Must match the `NSBonjourServices` entry in `Info.plist`.
    static let serviceType = "_ntp-challenge._tcp"

    /// Cap on an incoming framed payload so a malformed/hostile length prefix can't make us
    /// try to buffer an absurd amount. A challenge is a small JSON blob with one image.
    private nonisolated static let maxPayloadBytes = 8 * 1024 * 1024

    private(set) var state: State = .idle
    private(set) var receivedChallenge: FriendChallenge?
    private(set) var receivedResult: ChallengeResult?
    private(set) var discoveredPeers: [DiscoveredPeer] = []

    private let displayName: String
    private let queue = DispatchQueue(label: "com.ninetilespuzzle.challenge.nearby")

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?

    init(displayName: String) {
        self.displayName = displayName
    }

    // MARK: - Receiver role (advertise + accept)

    func startAdvertising() {
        stopBrowsing()
        do {
            let listener = try NWListener(using: Self.makeParameters())
            listener.service = NWListener.Service(name: displayName, type: Self.serviceType)
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in self.handleListenerState(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task { @MainActor in self.adopt(connection) }
            }
            listener.start(queue: queue)
            self.listener = listener
            state = .advertising
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        if state == .advertising { state = .idle }
    }

    private func handleListenerState(_ listenerState: NWListener.State) {
        if case .failed(let error) = listenerState {
            state = .failed(error.localizedDescription)
        }
    }

    private func adopt(_ connection: NWConnection) {
        // One challenge exchange at a time: reject extra dial-ins and stop advertising once
        // we've committed to a peer.
        guard self.connection == nil else {
            connection.cancel()
            return
        }
        listener?.cancel()
        listener = nil
        state = .connecting
        setup(connection, peerName: nil)
    }

    // MARK: - Sender role (browse + dial)

    func startBrowsing() {
        stopAdvertising()
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: Self.makeParameters())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { @MainActor in self.updatePeers(results) }
        }
        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in self.handleBrowserState(state) }
        }
        browser.start(queue: queue)
        self.browser = browser
        state = .browsing
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        discoveredPeers = []
        if state == .browsing { state = .idle }
    }

    func invite(_ peer: DiscoveredPeer) {
        stopBrowsing()
        state = .connecting
        setup(NWConnection(to: peer.endpoint, using: Self.makeParameters()), peerName: peer.name)
    }

    private func handleBrowserState(_ browserState: NWBrowser.State) {
        if case .failed(let error) = browserState {
            state = .failed(error.localizedDescription)
        }
    }

    private func updatePeers(_ results: Set<NWBrowser.Result>) {
        discoveredPeers = results.compactMap { result in
            guard case .service(let name, _, _, _) = result.endpoint else { return nil }
            return DiscoveredPeer(id: String(describing: result.endpoint), name: name, endpoint: result.endpoint)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Shared connection handling

    func send(_ challenge: FriendChallenge) throws {
        try sendWire(.challenge(challenge))
    }

    func send(_ result: ChallengeResult) throws {
        try sendWire(.result(result))
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        discoveredPeers = []
        receivedChallenge = nil
        receivedResult = nil
        state = .idle
    }

    private func setup(_ connection: NWConnection, peerName: String?) {
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] connectionState in
            guard let self else { return }
            Task { @MainActor in self.handleConnectionState(connectionState, peerName: peerName) }
        }
        Self.receiveNextMessage(on: connection) { [weak self] result in
            guard let self else { return }
            Task { @MainActor in self.handleReceive(result) }
        }
        connection.start(queue: queue)
    }

    private func handleConnectionState(_ connectionState: NWConnection.State, peerName: String?) {
        switch connectionState {
        case .ready:
            // Fall back to whatever we knew at dial time (the browsed name for the sender,
            // nothing for the receiver) until the peer's `hello` arrives with the real name.
            state = .connected(peerName: peerName ?? "a nearby player")
            try? sendWire(.hello(name: displayName))
        case .failed(let error):
            state = .failed(error.localizedDescription)
            teardownConnection()
        case .cancelled:
            if case .connected = state { state = .idle }
        default:
            break
        }
    }

    private func handleReceive(_ result: ReceiveResult) {
        switch result {
        case .message(let wire):
            switch wire {
            case .hello(let name):
                if case .connected = state { state = .connected(peerName: name) }
            case .challenge(let challenge):
                guard challenge.formatVersion <= FriendChallenge.currentFormatVersion else { return }
                receivedChallenge = challenge
            case .result(let result):
                receivedResult = result
            }
        case .closed:
            if case .connected = state { state = .idle }
            teardownConnection()
        case .failed(let message):
            state = .failed(message)
            teardownConnection()
        }
    }

    private func teardownConnection() {
        connection?.cancel()
        connection = nil
    }

    private func sendWire(_ message: Wire) throws {
        guard let connection else { throw NearbyError.notConnected }
        let payload = try JSONEncoder().encode(message)
        var length = UInt32(payload.count).bigEndian
        var framed = Data(bytes: &length, count: 4)
        framed.append(payload)
        connection.send(content: framed, completion: .contentProcessed { _ in })
    }

    // MARK: - Wire format

    /// The framed message envelope. `hello` exchanges display names so both ends can show the
    /// peer's real name; `challenge` carries the puzzle payload; `result` carries a played
    /// challenge's outcome back to the original sender.
    private nonisolated enum Wire: Codable {
        case hello(name: String)
        case challenge(FriendChallenge)
        case result(ChallengeResult)
    }

    private nonisolated enum ReceiveResult {
        case message(Wire)
        case closed
        case failed(String)
    }

    /// Reads one length-prefixed message (`UInt32` big-endian length, then that many JSON
    /// bytes) and reports it, then arms itself again for the next message. `nonisolated` so it
    /// can run on the connection's background queue; it only touches the connection it's given.
    private nonisolated static func receiveNextMessage(
        on connection: NWConnection,
        completion: @escaping @Sendable (ReceiveResult) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { data, _, isComplete, error in
            if let error {
                completion(.failed(error.localizedDescription))
                return
            }
            guard let data, data.count == 4 else {
                if isComplete { completion(.closed) }
                return
            }
            let length = data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length > 0, length <= UInt32(maxPayloadBytes) else {
                completion(.failed("Received an invalid message."))
                return
            }
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) {
                payload, _, isComplete, error in
                if let error {
                    completion(.failed(error.localizedDescription))
                    return
                }
                guard let payload, payload.count == Int(length) else {
                    if isComplete { completion(.closed) }
                    return
                }
                if let wire = try? JSONDecoder().decode(Wire.self, from: payload) {
                    completion(.message(wire))
                }
                receiveNextMessage(on: connection, completion: completion)
            }
        }
    }

    private nonisolated static func makeParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        // Allow AWDL/peer-to-peer links (Multipeer's default) in addition to shared Wi-Fi.
        parameters.includePeerToPeer = true
        return parameters
    }
}
