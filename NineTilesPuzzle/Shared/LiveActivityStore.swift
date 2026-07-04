//
//  LiveActivityStore.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import Foundation

/// Shared file storage bridging the app and its Live Activity widget extension. The app renders
/// a snapshot of the current board to a PNG here; the widget reads it back to draw the Lock
/// Screen and Dynamic Island. Both targets must carry the same App Group capability for the
/// container to resolve — without it every accessor returns `nil` and callers no-op.
///
/// Shared between the app and the widget extension: this file must be a member of both targets.
enum LiveActivityStore {
    /// App Group identifier. Must match the group added to *both* targets' Signing & Capabilities.
    static let appGroupID = "group.cilia.filippo.NineTilesPuzzle"

    /// The shared container both processes can read and write, or `nil` when the App Group
    /// capability isn't configured (e.g. in unit tests, or before setup completes).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Resolves a board snapshot filename to its full URL inside the shared container.
    static func boardImageURL(named name: String) -> URL? {
        containerURL?.appending(path: name)
    }
}
