//
//  MenuRouteDestinationView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/27/26.
//

import SwiftUI

/// Resolves a `GameRoute` pushed onto the menu's `NavigationStack` into its destination screen.
struct MenuRouteDestinationView: View {
    @Environment(GameSession.self) private var session

    let route: GameRoute
    @Binding var path: [GameRoute]

    var body: some View {
        switch route {
        case .game:
            PuzzleView()
        case .gridSizePicker:
            GridSizePickerView()
        case .achievements:
            AchievementsView()
        case .wallOfFame:
            WallOfFameView()
        case .gameModes:
            GameModeView()
        case .mediaPicker:
            MediaSourcePickerView()
        case .dailyCalendar:
            DailyChallengeCalendarView { day in
                session.enterDailyMode(for: day)
                beginGame(session: session, path: $path)
            }
        case .challengeHome:
            ChallengeHomeView(
                onAcceptChallenge: { challenge, nearbySession in
                    session.enterChallengeMode(with: challenge, nearbySession: nearbySession)
                    beginGame(session: session, path: $path)
                }
            )
        case .challengeHistory:
            ChallengeHistoryListView(
                onAcceptChallenge: { challenge in
                    session.enterChallengeMode(with: challenge)
                    beginGame(session: session, path: $path)
                }
            )
        }
    }
}
