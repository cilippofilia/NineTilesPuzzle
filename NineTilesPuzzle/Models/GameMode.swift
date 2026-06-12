//
//  GameMode.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import Foundation

enum GameMode: String, CaseIterable, Identifiable, Codable {
    case classic
    case slide
    case timeTrial
    case limitedMoves
    case zen
    case fog
    case chaos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .slide: "Slide"
        case .timeTrial: "Time Trial"
        case .limitedMoves: "Limited Moves"
        case .zen: "Zen Mode"
        case .fog: "Fog Mode"
        case .chaos: "Chaos Mode"
        }
    }

    var description: String {
        switch self {
        case .classic: "Solve the puzzle at your own pace"
        case .slide: "Solve the puzzle by sliding the pieces around"
        case .timeTrial: "Race against the clock to finish the puzzle"
        case .limitedMoves: "Solve the puzzle within a fixed number of moves"
        case .zen: "A relaxing, untimed experience with no streaks to break"
        case .fog: "Tiles are hidden until you move them"
        case .chaos: "This is not for the faint of heart. Is the image fully colored, mirrored, flipped or all of the above? Only one way to find out."
        }
    }

    var icon: String {
        switch self {
        case .classic: "square.grid.3x3.fill"
        case .slide: "hand.draw"
        case .timeTrial: "timer"
        case .limitedMoves: "figure.walk"
        case .zen: "leaf.fill"
        case .fog: "cloud.fog.fill"
        case .chaos: "tornado"
        }
    }

    var isAvailable: Bool {
        self == .classic || self == .slide
    }
}
