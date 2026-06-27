//
//  GameCenterService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import GameKit
import SwiftUI

@MainActor
@Observable
final class GameCenterService {
    private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let viewController {
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows
                        .first?.rootViewController?
                        .present(viewController, animated: true)
                } else {
                    isAuthenticated = GKLocalPlayer.local.isAuthenticated
                }
            }
        }
    }

    func showDashboard() {
        GKAccessPoint.shared.trigger(handler: {})
    }
}
