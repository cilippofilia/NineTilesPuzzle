//
//  SolvedPuzzleImage.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import CoreTransferable
import UniformTypeIdentifiers

/// Wraps the solved puzzle's PNG bytes so the completion toolbar's `ShareLink` can export it.
struct SolvedPuzzleImage: Transferable {
    let pngData: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.pngData }
    }
}
