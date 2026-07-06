//
//  ZoomedCardOverlay.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import SwiftUI

/// Full-screen zoom presentation for a rendered record card: a title capsule
/// above the card image, dismissed by tapping anywhere. Shared between the
/// Wall of Fame and the daily-challenge history calendar so zoomed cards look
/// and behave identically everywhere.
struct ZoomedCardOverlay: View {
    let cardImage: CGImage
    let title: String
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Color.clear.contentShape(.rect)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .buttonStyle(.plain)
        .overlay {
            VStack(spacing: 14) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: .capsule)

                Image(decorative: cardImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 18)
            }
            .padding(.horizontal, 28)
            .allowsHitTesting(false)
        }
    }
}
