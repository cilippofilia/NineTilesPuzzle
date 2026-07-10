//
//  PreviewViewController.swift
//  NineTilesPuzzlePreview
//
//  Created by Filippo Cilia on 7/10/26.
//

import ImageIO
import QuickLook
import UIKit

/// Renders the full-screen Quick Look preview for `.ntpchallenge` files — the tap-time
/// counterpart to `ThumbnailProvider`'s bubble icon. Without this extension the challenge UTI is
/// an opaque `public.data` blob with no way to render a preview, so a single tap in Messages/Files
/// does nothing; with it, tapping opens a real preview whose toolbar surfaces the "Open in Nine
/// Tiles Puzzle" action — the reliable route into the game.
final class PreviewViewController: UIViewController, QLPreviewingController {
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.backgroundColor = .secondarySystemBackground
        view.tintColor = .systemOrange
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.setCustomSpacing(6, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    // MARK: - QLPreviewingController

    func preparePreviewOfFile(at url: URL) async throws {
        guard case .success(let payload) = ChallengeFileCoder.decode(fileAt: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        configure(with: payload)
    }

    private func configure(with payload: ChallengePayload) {
        switch payload {
        case .invite(let challenge):
            titleLabel.text = "\(challenge.senderName)'s Challenge"
            subtitleLabel.text = "\(challenge.gameMode.title) · \(challenge.gridSize)×\(challenge.gridSize)"
            if let image = Self.boundedImage(from: challenge.imageData, maxPixelSize: 640) {
                imageView.contentMode = .scaleAspectFill
                imageView.image = image
            } else {
                showBadge()
            }
        case .result(let result):
            titleLabel.text = "\(result.responderName)'s Result"
            subtitleLabel.text = "\(result.moves) moves · \(Self.timeString(result.time))"
            showBadge()
        }
    }

    /// Falls back to a symbol when there's no puzzle image to show (result replies carry none,
    /// or a rare decode failure) so the preview never renders an empty grey square.
    private func showBadge() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 96, weight: .semibold)
        imageView.contentMode = .center
        imageView.image = UIImage(systemName: "square.grid.3x3.fill", withConfiguration: configuration)
    }

    /// Decodes a `maxPixelSize`-bounded bitmap via ImageIO rather than a full-resolution
    /// `UIImage(data:)`. Preview extensions run under a memory budget too — mirrors
    /// `ThumbnailProvider`'s bounded decode so a large sender photo can't get the extension
    /// jetsam-killed (which the system papers over with an empty preview).
    private static func boundedImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func timeString(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
