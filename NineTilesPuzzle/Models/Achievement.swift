//
//  Achievement.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import Foundation

struct Achievement: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let description: String
    let systemImage: String
    var isUnlocked: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case systemImage
    }
}
