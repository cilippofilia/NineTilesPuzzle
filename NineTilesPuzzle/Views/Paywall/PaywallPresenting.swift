//
//  PaywallPresenting.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/18/26.
//

import SwiftUI

extension View {
    /// Presents `PaywallView` whenever `context` becomes non-nil. The single reusable
    /// presentation mechanism every gated screen (game modes, media sources, Wall of Fame,
    /// Achievements, the Daily archive) uses instead of hand-rolling its own sheet.
    func paywallSheet(context: Binding<PaywallContext?>) -> some View {
        sheet(item: context) { PaywallView(context: $0) }
    }
}
