//
//  ShakeDetector.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import SwiftUI
import UIKit

/// Transparent UIKit bridge that detects device shake gestures.
/// Embed as a `.background` on any SwiftUI view to receive shake callbacks.
struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }

    final class ShakeViewController: UIViewController {
        var onShake: (() -> Void)?

        override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else { return }
            onShake?()
        }
    }
}
