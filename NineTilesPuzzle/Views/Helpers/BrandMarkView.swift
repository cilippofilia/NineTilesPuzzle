//
//  BrandMarkView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/12/26.
//

import SwiftUI

struct BrandMarkView: View {
    enum Layout {
        case horizontal
        case vertical
    }

    var layout: Layout = .horizontal
    var iconSize: CGFloat = 44
    var font: Font = .largeTitle

    private var puzzleGradient: LinearGradient {
        LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
    }

    var body: some View {
        switch layout {
        case .horizontal:
            HStack(spacing: 0) {
                icon
                title
            }
        case .vertical:
            VStack(spacing: 4) {
                icon
                title
            }
        }
    }

    private var icon: some View {
        Image(systemName: "puzzlepiece.fill")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: iconSize)
            .rotationEffect(.degrees(-45))
            .foregroundStyle(puzzleGradient)
    }

    private var title: some View {
        Text("Nine Tiles")
            .font(font)
            .bold()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

#Preview {
    VStack(spacing: 40) {
        BrandMarkView()

        BrandMarkView(layout: .vertical, iconSize: 36, font: .caption)
            .frame(width: 100, height: 100)
            .background(.quaternary)
    }
}
