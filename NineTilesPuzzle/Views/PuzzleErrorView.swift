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

    var body: some View {
        VStack {
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
