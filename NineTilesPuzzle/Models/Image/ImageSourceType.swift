//
//  ImageSourceType.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/3/26.
//

import Foundation

enum ImageSourceType: String, Codable {
    case random
    case local
    case mixed

    var label: String {
        switch self {
        case .random: "Internet"
        case .local: "From Photos"
        case .mixed: "Mixed"
        }
    }
}
