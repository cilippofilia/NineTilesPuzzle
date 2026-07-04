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

    /// The input currently wired into the session, held so `flip()` can swap it out for the
    /// opposite-facing camera without tearing the whole graph down.
    private var videoInput: AVCaptureDeviceInput?
    /// Which camera the session is currently feeding from. Starts on the back camera.
    private var currentPosition: AVCaptureDevice.Position = .back

    /// Bridges the one-shot `AVCapturePhotoCaptureDelegate` callback back to `capture()`'s
    /// awaiting caller. Set while a capture is in flight, cleared when it resolves.
    private var captureContinuation: CheckedContinuation<CGImage, Error>?

    /// Whether the device actually has a camera we can use. Availability only — authorization
    /// is requested separately in `configure()`. Mirrors how `.numbers` is offered
    /// conditionally: the Quick Snap media row is hidden entirely when this is false.
    static var isCameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    /// Whether both a front and a back camera exist, so offering a flip control makes sense.
    /// The flip button is hidden entirely when this is false (e.g. a device with one camera).
    static var canFlipCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            && AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    /// Binds the preview layer to the session on the main thread, where `CALayer` mutation
    /// belongs. Called before `configure()` so the layer is already live and laid out in the
    /// view hierarchy — the first frame the camera delivers paints immediately instead of
    /// waiting on the view being mounted only once the session is running.
    @MainActor
    func prepareForDisplay() {
        previewLayer.videoGravity = .resizeAspectFill
        if previewLayer.session == nil {
            previewLayer.session = session
        }
    }

    /// Requests camera authorization (if needed), builds the capture graph, and starts the
    /// session running. `startingPosition` is the camera the player last used, so Quick Snap
    /// reopens facing the same way. Throws `ImageSourceError.notAuthorized` when access is denied
    /// and `.providerUnavailable` when no usable camera/input exists (e.g. the Simulator).
    func configure(startingPosition: AVCaptureDevice.Position = .back) async throws {
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
                    try configureSession(preferredPosition: startingPosition)
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

    /// Swaps the live feed to the opposite-facing camera, leaving the countdown untouched.
    /// Falls back to the original input if the other camera can't be added, so a failed flip
    /// never leaves the session without a feed.
    func flip() {
        sessionQueue.async { [self] in
            let target: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: target),
                let newInput = try? AVCaptureDeviceInput(device: device)
            else {
                return
            }

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            if let videoInput {
                session.removeInput(videoInput)
            }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoInput = newInput
                currentPosition = target
            } else if let videoInput {
                // Restore the previous feed rather than ending up with no input at all.
                session.addInput(videoInput)
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

    private func configureSession(preferredPosition: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferredPosition)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            throw ImageSourceError.providerUnavailable
        }
        session.addInput(input)
        videoInput = input
        currentPosition = device.position

        guard session.canAddOutput(photoOutput) else {
            throw ImageSourceError.providerUnavailable
        }
        session.addOutput(photoOutput)
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
