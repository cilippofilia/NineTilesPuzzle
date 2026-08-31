//
//  DailyWidgetBackground.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/12/26.
//

import SwiftUI

/// The widget's background: a diagonal near-black gradient, a warm corner glow, and a large
/// rotated puzzle-piece watermark for texture. `markOffsetX` lets each family nudge the
/// watermark into its own empty space — e.g. the medium layout's gap between the mode text and
/// the Play CTA. Once today's seeded photo has loaded, the watermark shows that photo masked
/// into the piece's silhouette instead of the plain brand gradient.
struct DailyWidgetBackground: View {
    var markOffsetX: CGFloat = 40
    var showsWatermark: Bool = true
    var imageData: Data?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.05), Color(white: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.orange.opacity(0.35), .clear],
                center: .bottomTrailing,
                startRadius: 4,
                endRadius: 160
            )
            if showsWatermark {
                watermark
                    .rotationEffect(.degrees(18))
                    .offset(x: markOffsetX, y: -40)
            }
        }
    }

    @ViewBuilder
    private var watermark: some View {
        if let imageData, let photo = UIImage(data: imageData) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 130)
                .mask(BrandPuzzleMark(size: 130))
                .opacity(0.45)
        } else {
            BrandPuzzleMark(size: 130)
                .opacity(0.07)
        }
    }
}
