//
//  GameMode.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import Foundation

enum GameMode: String, CaseIterable, Identifiable, Codable {
    case slide
    case swap
    case timeTrial
    case limitedMoves
    case zen
    case fog
    case chaos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slide: "Slide"
        case .swap: "Swap"
        case .timeTrial: "Time Trial"
        case .limitedMoves: "Limited Moves"
        case .zen: "Zen Mode"
        case .fog: "Fog Mode"
        case .chaos: "Chaos Mode"
        }
    }

    var description: String {
        switch self {
        case .slide: "Solve the puzzle by sliding the pieces around"
        case .swap: "Swap any two tiles to solve the puzzle"
        case .timeTrial: "Race against the clock to finish the puzzle"
        case .limitedMoves: "Solve the puzzle within a fixed number of moves"
        case .zen: "A relaxing, untimed experience with no streaks to break"
        case .fog: "Tiles are hidden until you move them"
        case .chaos: "This is not for the faint of heart. Is the image fully colored, mirrored, flipped or all of the above? Only one way to find out."
        }
    }

    var icon: String {
        switch self {
        case .slide: "hand.draw"
        case .swap: "rectangle.2.swap"
        case .timeTrial: "timer"
        case .limitedMoves: "figure.walk"
        case .zen: "leaf.fill"
        case .fog: "cloud.fog.fill"
        case .chaos: "tornado"
        }
    }

    var isAvailable: Bool {
        self == .swap || self == .slide || self == .zen || self == .timeTrial || self == .limitedMoves
            || self == .chaos
    }
}
