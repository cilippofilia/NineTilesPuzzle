//
//  CompletionBannerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

struct CompletionBannerView: View {
    let streak: Int
    let isNewRecord: Bool

    var body: some View {
        VStack(spacing: 6) {
            if isNewRecord {
                Label("New Record!", systemImage: "trophy.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Color(hue: 0.12, saturation: 0.9, brightness: 0.85))
            }
            Text("Completed!")
                .font(.largeTitle)
                .bold()
            Label("\(streak)", systemImage: "flame.fill")
                .foregroundStyle(.orange)
                .bold()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    VStack(spacing: 20) {
        CompletionBannerView(streak: 7, isNewRecord: true)
        CompletionBannerView(streak: 3, isNewRecord: false)
    }
}
