//
//  GameRoute.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI

enum GameRoute: Hashable {
    case game
    case gridSizePicker
    case achievements
    case wallOfFame
    case gameModes
    case mediaPicker
    case dailyCalendar
    case challengeHome
    case challengeHistory
}

/// Resets the board and pushes `.game` — the standard way every "start playing" entry point
/// (Play button, Daily card, Quick Snap capture, deep links, challenge accept) begins a round.
@MainActor
func beginGame(session: GameSession, path: Binding<[GameRoute]>) {
    session.tiles = []
    session.isLoading = true
    path.wrappedValue.append(.game)
}
