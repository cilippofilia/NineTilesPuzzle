//
//  TileModel.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@MainActor
@Observable
final class TileModel: Identifiable, Equatable {
    let id: Int
    var currentIndex: Int
    var isLocked: Bool
    var hasBeenMoved: Bool

    init(
        id: Int,
        currentIndex: Int,
        isLocked: Bool,
        hasBeenMoved: Bool = false
    ) {
        self.id = id
        self.currentIndex = currentIndex
        self.isLocked = isLocked
        self.hasBeenMoved = hasBeenMoved
    }

    /// Whether this tile currently sits on its target grid position, regardless of `isLocked`.
    var isCorrect: Bool { currentIndex == id }
}

extension TileModel {
    static func == (lhs: TileModel, rhs: TileModel) -> Bool {
        return lhs.id == rhs.id
    }
}

extension TileModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case currentIndex
        case isLocked
        case hasBeenMoved
    }

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(Int.self, forKey: .id),
            currentIndex: container.decode(Int.self, forKey: .currentIndex),
            isLocked: container.decode(Bool.self, forKey: .isLocked),
            hasBeenMoved: (try? container.decode(Bool.self, forKey: .hasBeenMoved)) ?? false
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(currentIndex, forKey: .currentIndex)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(hasBeenMoved, forKey: .hasBeenMoved)
    }
}
