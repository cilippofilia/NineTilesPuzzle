//
//  PaywallLegalLinks.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/19/26.
//

import Foundation

/// Terms of Use and Privacy Policy links required on the paywall by App Review Guideline
/// 3.1.2 for auto-renewable subscriptions.
enum PaywallLegalLinks {
    /// Apple's Standard EULA — used because no custom End User License Agreement is
    /// configured in App Store Connect.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Hosted on GitHub Pages from the `docs/` folder of this repo. The same URL must also
    /// be set as the app's Privacy Policy URL in App Store Connect's App Information.
    static let privacyPolicy = URL(string: "https://cilippofilia.github.io/NineTilesPuzzle/privacy-policy.html")!
}
