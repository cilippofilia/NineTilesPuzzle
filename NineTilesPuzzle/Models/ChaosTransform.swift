//
//  ChaosTransform.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/26/26.
//

import CoreImage

/// A randomized, whole-image visual twist for Chaos Mode. Baked into the source image once
/// at shuffle time, before `ImageSlicer` ever sees it — every tile inherits the same
/// transform, so the solved puzzle still reads as one coherent (if mirrored/inverted/
/// pixelated) photo rather than a mosaic of independently-warped pieces. Orientation and
/// tone always pick exactly one option each (never a no-op); posterize/pixelate are
/// independent coin flips on top, so a game can stack 2-4 modifications total.
struct ChaosTransform {
    /// Mutually exclusive — picking more than one of these at once isn't meaningful, since
    /// e.g. a horizontal mirror plus a vertical flip is just a 180° rotation already in this
    /// list, so combining them would silently duplicate/cancel rather than add chaos.
    enum Orientation: CaseIterable {
        case mirror, flip, rotate90, rotate180, rotate270
    }

    /// Mutually exclusive — stacking these is mostly redundant rather than additive (a hue
    /// shift is invisible once desaturated; sepia already bakes in its own desaturation).
    enum Tone {
        case desaturate
        case invert
        case hueShift(angle: Double)
        case sepia

        static func random() -> Tone {
            switch Int.random(in: 0..<4) {
            case 0: return .desaturate
            case 1: return .invert
            case 2: return .hueShift(angle: Double.random(in: 0..<(2 * .pi)))
            default: return .sepia
            }
        }
    }

    let orientation: Orientation
    let tone: Tone
    let posterize: Bool
    let pixelate: Bool

    static func random() -> ChaosTransform {
        ChaosTransform(
            orientation: Orientation.allCases.randomElement()!,
            tone: .random(),
            posterize: Bool.random(),
            pixelate: Bool.random()
        )
    }

    private static let context = CIContext()

    /// Applies orientation, tone, and any optional structural filters to `image`, in that
    /// order. `gridSize` scales the pixelate filter so blocks stay sized per-tile rather than
    /// per-image — a fixed block size would flatten whole tiles to a single color on larger
    /// grids, making them unsolvable-by-eye rather than just harder.
    func apply(to image: CGImage, gridSize: Int) -> CGImage {
        var ciImage = oriented(CIImage(cgImage: image))
        ciImage = toned(ciImage)

        if posterize {
            ciImage = ciImage.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 6])
        }

        if pixelate {
            let blocksPerTileEdge: CGFloat = 6
            let scale = max(1, CGFloat(image.width) / (CGFloat(gridSize) * blocksPerTileEdge))
            ciImage = ciImage.applyingFilter("CIPixellate", parameters: [
                "inputScale": scale,
                "inputCenter": CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY)
            ])
        }

        guard let result = Self.context.createCGImage(ciImage, from: ciImage.extent) else { return image }
        return result
    }

    private func oriented(_ image: CIImage) -> CIImage {
        switch orientation {
        case .mirror: image.oriented(.upMirrored)
        case .flip: image.oriented(.downMirrored)
        case .rotate90: image.oriented(.right)
        case .rotate180: image.oriented(.down)
        case .rotate270: image.oriented(.left)
        }
    }

    private func toned(_ image: CIImage) -> CIImage {
        switch tone {
        case .desaturate:
            image.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0])
        case .invert:
            image.applyingFilter("CIColorInvert")
        case .hueShift(let angle):
            image.applyingFilter("CIHueAdjust", parameters: ["inputAngle": angle])
        case .sepia:
            image.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 1.0])
        }
    }
}
