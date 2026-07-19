//
//  PaywallLegalFooterView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// The auto-renewal disclosure and the Restore Purchase / Terms of Use / Privacy Policy row,
/// pinned to the bottom of `PaywallView` via `.safeAreaInset(edge: .bottom)` — kept on screen
/// at all times, rather than scrolling away or getting clipped mid-scroll, since Guideline
/// 3.1.2 requires this disclosure and these links stay immediately visible on the paywall.
struct PaywallLegalFooterView: View {
    @Environment(\.openURL) private var openURL

    let disclosureText: String
    let isRestoring: Bool
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(disclosureText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 6) {
                if isRestoring {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Button("Restore Purchase", action: onRestore)
                }

                Text("•")
                    .foregroundStyle(.tertiary)

                Button("Terms of Use") { openURL(PaywallLegalLinks.termsOfUse) }

                Text("•")
                    .foregroundStyle(.tertiary)

                Button("Privacy Policy") { openURL(PaywallLegalLinks.privacyPolicy) }
            }
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        Spacer()
        PaywallLegalFooterView(
            disclosureText: "Premium Pass is $1.99/month, charged to your Apple ID account. It automatically "
                + "renews unless canceled at least 24 hours before the end of the current period.",
            isRestoring: false,
            onRestore: {}
        )
    }
    .background(.black)
}
