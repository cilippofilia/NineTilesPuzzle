//
//  DeepLink.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/5/26.
//

import Foundation

/// The `ninetilespuzzle://` routes widgets use to open a specific place in the app.
///
/// Formats: `ninetilespuzzle://daily`, `ninetilespuzzle://resume`,
/// `ninetilespuzzle://mode/<gameMode>/<gridSize>` (the size segment is optional),
/// `ninetilespuzzle://paywall`.
///
/// Shared between the app and the widget extension: this file must be a member of both targets.
enum DeepLink: Equatable {
    case daily
    case resume
    case mode(GameMode, gridSize: Int?)
    /// A locked widget/Live Activity placeholder was tapped — open straight to the paywall.
    case paywall

    static let scheme = "ninetilespuzzle"
    static let gridSizeRange = 3...8

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .daily:
            components.host = "daily"
        case .resume:
            components.host = "resume"
        case .mode(let mode, let gridSize):
            components.host = "mode"
            components.path = if let gridSize {
                "/\(mode.rawValue)/\(gridSize)"
            } else {
                "/\(mode.rawValue)"
            }
        case .paywall:
            components.host = "paywall"
        }
        // URLComponents with a static scheme and validated segments always resolves.
        return components.url ?? URL(string: "\(Self.scheme)://")!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host
        else { return nil }

        let segments = components.path.split(separator: "/").map(String.init)

        switch host {
        case "daily" where segments.isEmpty:
            self = .daily
        case "resume" where segments.isEmpty:
            self = .resume
        case "paywall" where segments.isEmpty:
            self = .paywall
        case "mode":
            guard let first = segments.first, let mode = GameMode(rawValue: first) else { return nil }
            switch segments.count {
            case 1:
                self = .mode(mode, gridSize: nil)
            case 2:
                guard let size = Int(segments[1]), Self.gridSizeRange.contains(size) else { return nil }
                self = .mode(mode, gridSize: size)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
