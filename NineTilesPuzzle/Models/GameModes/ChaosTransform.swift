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
/// tone always pick exactly one option each (never a no-op); posterize is an independent
/// coin flip on top, while pixelate is weighted lower since its block size reads as a much
/// stronger effect than the others, so a game can stack 2-4 modifications total.
nonisolated struct ChaosTransform {
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
            // Pixelate reads as much chunkier than the other modifiers at the same block
            // size, so it gets a lower hit rate than posterize's 50/50 to keep it feeling
            // like an occasional twist rather than the default look.
            pixelate: Double.random(in: 0..<1) < 0.25
        )
    }

    private static let context = CIContext()

    /// Applies orientation, tone, and any optional structural filters to `image`, in that order.
    func apply(to image: CGImage) -> CGImage {
        var ciImage = oriented(CIImage(cgImage: image))
        ciImage = toned(ciImage)

        if posterize {
            ciImage = ciImage.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 6])
        }

        if pixelate {
            // Block size is a fraction of the whole photo, not the per-tile size — source
            // resolution varies a lot (camera vs. library vs. remote photos aren't resized
            // before this runs), so anchoring to tile size made the effect look wildly
            // different game to game. Targeting ~128 blocks across the whole image keeps it
            // looking like a recognizable low-res photo rather than a mosaic of flat blocks.
            let targetBlocksAcrossImage: CGFloat = 128
            let scale = max(1, CGFloat(image.width) / targetBlocksAcrossImage)
            ciImage = ciImage.applyingFilter("CIPixellate", parameters: [
                "inputScale": scale,
                "inputCenter": CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY)
            ])
            ciImage = zoomedToHideEdgeBand(ciImage, blockSize: scale)
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

    /// CIPixellate's block grid is centered on the image, so the outermost ring of blocks at
    /// each edge is partial — and since that ring lines up exactly with the puzzle's border
    /// tiles, it was an easy tell for which pieces sit on the edge. Cropping that partial-block
    /// margin away and scaling the clean interior back up to fill the frame keeps every tile's
    /// pixelation looking uniform.
    private func zoomedToHideEdgeBand(_ image: CIImage, blockSize: CGFloat) -> CIImage {
        let extent = image.extent
        let inset = extent.insetBy(dx: blockSize, dy: blockSize)
        guard inset.width > 0, inset.height > 0 else { return image }

        let zoomX = extent.width / inset.width
        let zoomY = extent.height / inset.height
        return image
            .cropped(to: inset)
            .transformed(by: CGAffineTransform(translationX: -inset.minX, y: -inset.minY))
            .transformed(by: CGAffineTransform(scaleX: zoomX, y: zoomY))
            .cropped(to: extent)
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
