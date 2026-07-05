//
//  StatsConfigurationIntent.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/5/26.
//

import AppIntents

/// The game modes offered by the Streaks & Records widget's edit sheet. Widget-local mirror
/// of `GameMode` (bridged via matching raw values) so the shared enum never has to import
/// AppIntents; Zen is deliberately absent — it tracks no streaks or records by design.
enum WidgetGameMode: String, AppEnum {
    case slide
    case swap
    case timeTrial
    case limitedMoves
    case fog
    case chaos

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Game Mode"

    static let caseDisplayRepresentations: [WidgetGameMode: DisplayRepresentation] = [
        .slide: "Slide",
        .swap: "Swap",
        .timeTrial: "Time Trial",
        .limitedMoves: "Limited Moves",
        .fog: "Haze",
        .chaos: "Chaos Mode"
    ]

    var gameMode: GameMode {
        GameMode(rawValue: rawValue) ?? .slide
    }
}

/// The grid sizes offered by the Streaks & Records widget's edit sheet, with the same
/// difficulty labels the app's Grid Size picker uses.
enum WidgetGridSize: Int, AppEnum {
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Grid Size"

    static let caseDisplayRepresentations: [WidgetGridSize: DisplayRepresentation] = [
        .three: "3 × 3 (Easy)",
        .four: "4 × 4 (Medium)",
        .five: "5 × 5 (Hard)",
        .six: "6 × 6 (Expert)",
        .seven: "7 × 7 (Master)",
        .eight: "8 × 8 (Insane)"
    ]
}

/// Configuration for the Streaks & Records widget: which mode and grid size to show.
struct StatsConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Mode & Grid"
    static let description = IntentDescription("Choose which game mode and grid size to track.")

    @Parameter(title: "Game Mode", default: .slide)
    var mode: WidgetGameMode

    @Parameter(title: "Grid Size", default: .three)
    var gridSize: WidgetGridSize
}
