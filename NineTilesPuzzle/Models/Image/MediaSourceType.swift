//
//  MediaSourceType.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/3/26.
//

import Foundation

enum MediaSourceType: String, Codable {
    case random
    case local
    case mixed
    case numbers
    case camera

    var label: String {
        switch self {
        case .random: "Internet"
        case .local: "From Photos"
        case .mixed: "Mixed Pics"
        case .numbers: "Numbers"
        case .camera: "Quick Snap"
        }
    }

    /// Whether this source is usable without a premium unlock. Only the web/algorithmic
    /// sources are free; personal-photo sources (`.local`, `.mixed`, `.camera`) are a
    /// Hard-Feature Gate premium upgrade.
    var isFree: Bool {
        self == .random || self == .numbers
    }
}
