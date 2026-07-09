//
//  NearbyPeerPickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/9/26.
//

import SwiftUI

/// Native replacement for Multipeer's `MCBrowserViewController`: lists the peers the
/// `NWBrowser` has found and dials the one the user taps.
struct NearbyPeerPickerView: View {
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
