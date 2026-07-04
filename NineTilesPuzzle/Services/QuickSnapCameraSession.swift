//
//  QuickSnapCameraSession.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import AVFoundation
import UIKit

/// Owns the `AVCaptureSession` used by Quick Snap. All AVFoundation work runs on a private
/// serial queue (the pattern Apple's capture pipeline requires), so the type synchronizes
/// itself and is safe to hand across actor boundaries. The SwiftUI layer only touches
/// `previewLayer` (created once, read on the main thread) and the async entry points below.
final class QuickSnapCameraSession: NSObject, @unchecked Sendable {
    /// The layer the preview view displays. Its `session` is wired up during configuration.
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.ninetilespuzzle.quicksnap.camera")

    /// Bridges the one-shot `AVCapturePhotoCaptureDelegate` callback back to `capture()`'s
    /// awaiting caller. Set while a capture is in flight, cleared when it resolves.
    private var captureContinuation: CheckedContinuation<CGImage, Error>?

    /// Whether the device actually has a camera we can use. Availability only — authorization
    /// is requested separately in `configure()`. Mirrors how `.numbers` is offered
    /// conditionally: the Quick Snap media row is hidden entirely when this is false.
    static var isCameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    /// Requests camera authorization (if needed), builds the capture graph, and starts the
    /// session running. Throws `ImageSourceError.notAuthorized` when access is denied and
    /// `.providerUnavailable` when no usable camera/input exists (e.g. the Simulator).
    func configure() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw ImageSourceError.notAuthorized }
        default:
            throw ImageSourceError.notAuthorized
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    try configureSession()
                    session.startRunning()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Grabs the current frame as an upright `CGImage`. Called when the countdown hits zero.
    func capture() async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(throwing: ImageSourceError.providerUnavailable)
                    return
                }
                captureContinuation = continuation
                let settings = AVCapturePhotoSettings()
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    /// Stops the running session. Safe to call more than once.
    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Session graph

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            throw ImageSourceError.providerUnavailable
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            throw ImageSourceError.providerUnavailable
        }
        session.addOutput(photoOutput)

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}

extension QuickSnapCameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let continuation = captureContinuation
        captureContinuation = nil

        if let error {
            continuation?.resume(throwing: error)
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data),
            let cgImage = image.uprightCGImage()
        else {
            continuation?.resume(throwing: ImageSourceError.invalidImageData)
            return
        }
        continuation?.resume(returning: cgImage)
    }
}

private extension UIImage {
    /// Bakes any orientation metadata into the pixels and returns the resulting `CGImage`, so
    /// the puzzle slicer receives an upright image rather than one that only looks correct once
    /// a `UIImage.Orientation` flag is applied.
    func uprightCGImage() -> CGImage? {
        guard imageOrientation != .up else { return cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let redrawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return redrawn.cgImage
    }
}
