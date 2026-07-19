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
            switch context.icon {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .frame(width: 76, height: 76)
                    .glassEffect(.regular, in: .circle)
            case .appIcon:
                Image("PaywallAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .clipShape(.rect(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
            }

            Text(context.headline)
                .font(.title2)
                .bold()

            if !context.subheadline.isEmpty {
                Text(context.subheadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    PaywallHeaderView(context: .gameMode(.fog))
}
