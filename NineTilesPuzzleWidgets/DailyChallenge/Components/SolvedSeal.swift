//
//  SolvedSeal.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// A green-gradient checkmark seal marking today's challenge as solved.
struct SolvedSeal: View {
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.46, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.green.gradient, in: .circle)
    }
}
