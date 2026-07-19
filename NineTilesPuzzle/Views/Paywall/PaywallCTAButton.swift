//
//  PaywallCTAButton.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import SwiftUI

/// The single confirm button at the bottom of `PaywallView`'s plan list — its title reflects
/// whichever plan is currently selected above it.
struct PaywallCTAButton: View {
    let title: String
    let isPurchasing: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isPurchasing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(title)
                    .contentTransition(.opacity)
                    .bold()
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(isDisabled)
        .animation(.snappy, value: title)
    }
}

#Preview {
    VStack(spacing: 12) {
        PaywallCTAButton(title: "Unlock Lifetime Access", isPurchasing: false, isDisabled: false, action: {})
        PaywallCTAButton(title: "Start Premium Pass", isPurchasing: true, isDisabled: true, action: {})
    }
    .padding()
}
