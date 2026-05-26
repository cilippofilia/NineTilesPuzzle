//
//  TileModel.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@Observable
final class TileModel: Identifiable, Equatable {
    let id: Int
    var currentIndex: Int
    var isLocked: Bool

    init(id: Int, currentIndex: Int, isLocked: Bool) {
        self.id = id
        self.currentIndex = currentIndex
        self.isLocked = isLocked
    }

    var isInCorrectPosition: Bool {
        id == currentIndex
    }
}

extension TileModel {
    static func == (lhs: TileModel, rhs: TileModel) -> Bool {
        return lhs.id == rhs.id
    }
}

extension TileModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, currentIndex, isLocked
    }

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(Int.self, forKey: .id),
            currentIndex: container.decode(Int.self, forKey: .currentIndex),
            isLocked: container.decode(Bool.self, forKey: .isLocked)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(currentIndex, forKey: .currentIndex)
        try container.encode(isLocked, forKey: .isLocked)
    }
}
