//
//  PuzzleErrorView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct PuzzleErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onSwitchToPhotos: () -> Void

    var body: some View {
        VStack {
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
            if case ImageSourceError.providerUnavailable = error {
                Button("Switch to Photos", action: onSwitchToPhotos)
                    .buttonStyle(.borderedProminent)
                Button("Try again", action: onRetry)
            } else {
                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
