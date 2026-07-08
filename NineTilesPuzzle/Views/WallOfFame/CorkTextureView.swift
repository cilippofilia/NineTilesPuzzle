//
//  CorkTextureView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// The Wall of Fame's cork board background — a bundled photo texture, which replaced an
/// earlier procedural `Canvas` whose ~27K-ellipse first rasterization landed on the main
/// thread mid-push-transition.
struct CorkTextureView: View {
    var body: some View {
        Image(.corkBg)
            .resizable()
            .scaledToFill()
            // The landscape texture fill-cropped into a portrait frame overhangs
            // horizontally; unclipped, that overhang would draw over the outgoing
            // screen during the navigation push.
            .clipped()
    }
}

#Preview {
    CorkTextureView()
        .ignoresSafeArea()
}
