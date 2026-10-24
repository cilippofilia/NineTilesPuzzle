//
//  PuzzleSidePanelLayout.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 10/24/26.
//

import SwiftUI

/// Decides whether the puzzle screen splits into the board on one side and a live
/// stats/results panel on the other, rather than floating its HUD over and under the
/// board. The decision follows the space `PuzzleView` actually has — never the device —
/// so it applies equally to an iPad, an unfolded iPhone Duo, or any other window that's
/// wide enough, and falls back to the stacked layout as soon as the window narrows
/// (Split View, Slide Over, a folded Duo, portrait).
enum PuzzleSidePanelLayout {
    /// The puzzle screen's size, plus where the display folds within it, if it does.
    nonisolated struct ContentGeometry: Equatable {
        var size: CGSize = .zero
        /// The iPhone Duo folding region in the screen's own coordinates, or nil on a
        /// display that doesn't fold.
        var divisionFrame: CGRect?
    }

    /// Where the board's area ends and the panel's begins.
    struct Split: Equatable {
        /// Width taken off the trailing edge of the board's area.
        var boardTrailingInset: CGFloat
        /// Width of the panel's area, measured from the trailing edge.
        var panelWidth: CGFloat
    }

    /// Below this width-to-height ratio a centered square board already fills most of the
    /// width, so splitting the screen would shrink it rather than use spare space.
    static let minimumAspectRatio: CGFloat = 1.15

    /// The split between board and panel, or nil when the stacked layout should be used.
    /// On a display with a vertical fold the board ends where the fold starts and the panel
    /// begins where it ends, so nothing touchable ever sits on it. That's not the middle of
    /// the screen: the iPhone Duo's vertical system bar narrows one side. Anywhere else the
    /// space splits evenly.
    static func split(for geometry: ContentGeometry, hasRegularSizeClasses: Bool) -> Split? {
        let size = geometry.size
        guard hasRegularSizeClasses, size.height > 0, size.width / size.height >= minimumAspectRatio else {
            return nil
        }
        if let fold = geometry.divisionFrame, fold.height > fold.width, fold.minX > 0, fold.maxX < size.width {
            return Split(boardTrailingInset: size.width - fold.minX, panelWidth: size.width - fold.maxX)
        }
        return Split(boardTrailingInset: size.width / 2, panelWidth: size.width / 2)
    }

    /// The folding region within `proxy`, whether or not the device is currently folded
    /// (`includeInactive`): the board and panel keep clear of the fold even when the
    /// display lies flat, so neither moves as the device folds.
    nonisolated static func divisionFrame(in proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return proxy.reservedRegions(kind: .division, options: .includeInactive).first?.frame
    }
}
