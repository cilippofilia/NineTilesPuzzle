//
//  ZoomedCardOverlay.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import SwiftUI

/// Full-screen zoom presentation for a rendered record card: a title capsule
/// above the card image, dismissed by tapping anywhere, with an optional footer
/// (action buttons, captions) below the card. Shared between the Wall of Fame
/// and the daily-challenge history calendar so zoomed cards look and behave
/// identically everywhere.
struct ZoomedCardOverlay<Footer: View>: View {
    let cardImage: CGImage
    let title: String
    let onDismiss: () -> Void
    private let footer: Footer

    init(
        cardImage: CGImage,
        title: String,
        onDismiss: @escaping () -> Void,
        @ViewBuilder footer: () -> Footer
    ) {
        self.cardImage = cardImage
        self.title = title
        self.onDismiss = onDismiss
        self.footer = footer()
    }

    var body: some View {
        Button(action: onDismiss) {
            Color.clear.contentShape(.rect)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .buttonStyle(.plain)
        .overlay {
            VStack(spacing: 14) {
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
                // The title and card never swallow taps — anywhere outside the
                // footer falls through to the full-screen dismiss button behind.
                .allowsHitTesting(false)

                footer
            }
            .padding(.horizontal, 28)
        }
    }
}

extension ZoomedCardOverlay where Footer == EmptyView {
    /// A zoomed card with nothing below it — the Wall of Fame's presentation.
    init(cardImage: CGImage, title: String, onDismiss: @escaping () -> Void) {
        self.init(cardImage: cardImage, title: title, onDismiss: onDismiss) {
            EmptyView()
        }
    }
}
