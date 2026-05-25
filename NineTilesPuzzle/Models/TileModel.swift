//
//  TileModel.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@Observable
class TileModel: Identifiable, Equatable {
    let id: Int
    let currentIndex: Int
    let isLocked: Bool

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
