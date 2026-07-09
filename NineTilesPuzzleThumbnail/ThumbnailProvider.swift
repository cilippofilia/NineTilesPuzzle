//
//  ThumbnailProvider.swift
//  NineTilesPuzzleThumbnail
//
//  Created by Filippo Cilia on 7/9/26.
//

import ImageIO
import QuickLookThumbnailing
import UIKit

/// Renders the Messages/Files/Finder preview for `.ntpchallenge` files — without this, the
/// system falls back to a plain generic document icon since the UTI has no bundled artwork.
final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        guard let payload = ChallengeFileCoder.decode(fileAt: request.fileURL) else {
            handler(nil, CocoaError(.fileReadCorruptFile))
            return
        }

        // `FriendChallenge.imageData` is the sender's full-resolution photo (ChallengeImageCodec
        // does no resizing) — a thumbnail extension runs under a tight memory budget, so decode a
        // bounded thumbnail here rather than the naive full-size `UIImage(data:)`, mirroring
        // `ChallengeStore.image(for:)`'s use of `kCGImageSourceThumbnailMaxPixelSize` for the same
        // reason. A full decode risks the extension being jetsam-killed, which the system quietly
        // papers over with the generic document icon instead of surfacing an error.
        let maxPixelSize = max(request.maximumSize.width, request.maximumSize.height) * request.scale
        let image = ChallengeThumbnailRenderer.decodeBoundedImage(from: payload, maxPixelSize: maxPixelSize)

        let reply = QLThumbnailReply(contextSize: request.maximumSize) {
            ChallengeThumbnailRenderer.draw(payload, image: image, in: request.maximumSize)
            return true
        }
        handler(reply, nil)
    }
}

/// Draws directly into the current `CGContext` that Quick Look has already set up for the
/// reply's drawing block — no intermediate `UIImage` needed.
private enum ChallengeThumbnailRenderer {
    /// Decodes at most a `maxPixelSize`-bounded bitmap via `ImageIO`'s thumbnail generation,
    /// which never allocates a full-resolution decode buffer — safe under a thumbnail
    /// extension's tight memory budget. Returns `nil` for `.result` payloads (no image).
    static func decodeBoundedImage(from payload: ChallengePayload, maxPixelSize: CGFloat) -> UIImage? {
        guard case .invite(let challenge) = payload,
              let source = CGImageSourceCreateWithData(challenge.imageData as CFData, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func draw(_ payload: ChallengePayload, image: UIImage?, in size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.22).addClip()

        drawBackgroundGradient(in: rect)

        let caption: String
        switch payload {
        case .invite(let challenge):
            caption = "\(challenge.senderName)'s Challenge"
        case .result(let result):
            caption = "\(result.responderName)'s Result"
        }

        if let image {
            drawPuzzleImage(image, in: rect)
        } else {
            drawBadge(in: rect)
        }

        drawCaption(caption, in: rect)
    }

    private static func drawBackgroundGradient(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 1, green: 0.8, blue: 0, alpha: 1).cgColor,
                    UIColor(red: 1, green: 0.2196, blue: 0.2353, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 1]
              )
        else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }

    private static func drawPuzzleImage(_ image: UIImage, in rect: CGRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let inset = rect.width * 0.08
        let imageRect = rect.insetBy(dx: inset, dy: inset).offsetBy(dx: 0, dy: -rect.height * 0.04)
        let path = UIBezierPath(roundedRect: imageRect, cornerRadius: rect.width * 0.06)

        UIColor.white.setFill()
        path.fill()

        UIGraphicsGetCurrentContext()?.saveGState()
        path.addClip()

        let scale = max(imageRect.width / image.size.width, imageRect.height / image.size.height)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawOrigin = CGPoint(x: imageRect.midX - drawSize.width / 2, y: imageRect.midY - drawSize.height / 2)
        image.draw(in: CGRect(origin: drawOrigin, size: drawSize))

        UIGraphicsGetCurrentContext()?.restoreGState()
    }

    private static func drawBadge(in rect: CGRect) {
        let configuration = UIImage.SymbolConfiguration(pointSize: rect.width * 0.34, weight: .semibold)
        guard let symbol = UIImage(systemName: "square.grid.3x3.fill", withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        else { return }
        let symbolRect = CGRect(
            x: rect.midX - symbol.size.width / 2,
            y: rect.midY - symbol.size.height / 2 - rect.height * 0.05,
            width: symbol.size.width,
            height: symbol.size.height
        )
        symbol.draw(in: symbolRect)
    }

    private static func drawCaption(_ text: String, in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let scrimRect = CGRect(x: rect.minX, y: rect.maxY - rect.height * 0.3, width: rect.width, height: rect.height * 0.3)
        if let scrim = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0.55).cgColor,
            ] as CFArray,
            locations: [0, 1]
        ) {
            context.saveGState()
            context.clip(to: scrimRect)
            context.drawLinearGradient(
                scrim,
                start: CGPoint(x: scrimRect.midX, y: scrimRect.minY),
                end: CGPoint(x: scrimRect.midX, y: scrimRect.maxY),
                options: []
            )
            context.restoreGState()
        }

        let fontSize = rect.width * 0.09
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle,
        ]
        let textRect = CGRect(
            x: rect.width * 0.08,
            y: rect.maxY - fontSize * 1.8,
            width: rect.width * 0.84,
            height: fontSize * 1.4
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}
