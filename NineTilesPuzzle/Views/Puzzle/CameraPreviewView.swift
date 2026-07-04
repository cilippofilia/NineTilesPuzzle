//
//  CameraPreviewView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import AVFoundation
import SwiftUI
import UIKit

/// Displays the live feed from a `QuickSnapCameraSession` by hosting its preview layer.
/// AVFoundation has no SwiftUI-native preview, so this bridges through UIKit.
struct CameraPreviewView: UIViewRepresentable {
    let cameraSession: QuickSnapCameraSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer = cameraSession.previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    /// Keeps the hosted preview layer sized to the view; the layer is added as a sublayer
    /// rather than via `layerClass` so its lifetime stays owned by `QuickSnapCameraSession`.
    final class PreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let previewLayer {
                    layer.addSublayer(previewLayer)
                    setNeedsLayout()
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
