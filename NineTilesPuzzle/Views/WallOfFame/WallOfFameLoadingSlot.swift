//
//  WallOfFameLoadingSlot.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// A neutral stand-in shown in a Wall of Fame slot whose card exists on disk but whose
/// thumbnail is still decoding off the main actor — visually a blank pinned card, so the
/// board's layout is stable and the decoded image can fade in without a reflow.
struct WallOfFameLoadingSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.white.opacity(0.12))
            .frame(width: 160, height: 192)
            .overlay(alignment: .top) {
                Text("📍")
                    .font(.title3)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .padding(.top, -8)
            }
    }
}

#Preview {
    WallOfFameLoadingSlot()
        .padding(40)
        .background(Color.black)
}
