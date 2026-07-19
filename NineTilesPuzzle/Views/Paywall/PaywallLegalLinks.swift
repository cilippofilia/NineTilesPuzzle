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

    /// ⚠️ PLACEHOLDER — `example.com` is a non-resolving reserved domain (RFC 2606).
    /// App Review requires a functional Privacy Policy link, so this MUST be replaced with
    /// a real, hosted Privacy Policy URL (and the same URL set as the app's Privacy Policy
    /// URL in App Store Connect's App Information) before submitting for review.
    static let privacyPolicy = URL(string: "https://example.com/ninetilespuzzle/privacy-policy")!
}
