//
//  PaywallHeaderView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import SwiftUI

/// The contextual headline block at the top of `PaywallView` — icon, feature name, and a
/// one-line blurb pulled from whatever `PremiumFeature` triggered the sheet.
struct PaywallHeaderView: View {
    let context: PaywallContext

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: context.icon)
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text(context.headline)
                .font(.title2)
                .bold()

            if !context.subheadline.isEmpty {
                Text(context.subheadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    PaywallHeaderView(context: .gameMode(.fog))
}
