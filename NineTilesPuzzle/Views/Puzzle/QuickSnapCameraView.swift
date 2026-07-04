//
//  QuickSnapCameraView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import AVFoundation
import SwiftUI

/// Full-screen Quick Snap capture flow: a live camera feed with a countdown ring. There is no
/// shutter button and no retake — when the countdown hits zero the current frame is captured
/// automatically and handed back through `onCapture`. Committing to whatever's in frame is the
/// whole point of the mode.
struct QuickSnapCameraView: View {
    /// Seconds on the clock before auto-capture. Callers pass the player's chosen Quick Snap
    /// timer from Settings (`GameSession.currentQuickSnapDuration`).
    let shotDuration: Double
    let onCapture: (CGImage) -> Void
    let onCancel: () -> Void

    @Environment(SettingsStore.self) private var settings

    @State private var cameraSession = QuickSnapCameraSession()
    @State private var remaining: Double
    @State private var isReady = false
    @State private var errorMessage: String?
    @State private var hasCaptured = false

    init(shotDuration: Double, onCapture: @escaping (CGImage) -> Void, onCancel: @escaping () -> Void) {
        self.shotDuration = shotDuration
        self.onCapture = onCapture
        self.onCancel = onCancel
        _remaining = State(initialValue: shotDuration)
    }

    /// Whole seconds left on the clock, matching the big number the overlay shows. Backs the
    /// per-second countdown haptic so a tick lands in sync with each visible tick down.
    private var secondsRemaining: Int { Int(remaining.rounded(.up)) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let errorMessage {
                QuickSnapErrorView(message: errorMessage, onDismiss: onCancel)
            } else {
                // The whole viewfinder is a shutter: tapping snaps the current frame right away
                // instead of waiting for zero, the way the Fitness app's pre-workout countdown
                // lets you skip ahead. The countdown is only a ceiling, not a mandatory wait.
                Button {
                    Task { await fireCapture() }
                } label: {
                    ZStack {
                        // Mounted up front (not gated on `isReady`) so the preview layer is live
                        // and laid out before the session starts delivering frames — the first
                        // frame paints immediately instead of after the view is built. The layer
                        // shows the black background beneath until frames flow.
                        CameraPreviewView(cameraSession: cameraSession)
                            .ignoresSafeArea()
                            .opacity(isReady ? 1 : 0)

                        if isReady {
                            QuickSnapCountdownOverlay(remaining: remaining, total: shotDuration)
                        } else {
                            QuickSnapLoadingView()
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isReady)
                .accessibilityLabel("Snap photo now")
            }
        }
        .overlay(alignment: .topLeading) {
            if errorMessage == nil {
                Button("Cancel", systemImage: "xmark") {
                    cameraSession.stop()
                    onCancel()
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.white)
                .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            if errorMessage == nil && isReady && QuickSnapCameraSession.canFlipCamera {
                Button("Flip camera", systemImage: "arrow.triangle.2.circlepath.camera") {
                    // Remember the new facing so Quick Snap reopens the same way next time.
                    settings.setQuickSnapUsesFrontCamera(!settings.quickSnapUsesFrontCamera)
                    cameraSession.flip()
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.white)
                .padding()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isReady)
        // A tick on each second down, then a firmer beat when the shutter actually fires — the
        // countdown you feel as well as see, like the Fitness app's pre-workout timer.
        .sensoryFeedback(.selection, trigger: secondsRemaining) { oldValue, newValue in
            settings.hapticsEnabled && isReady && newValue < oldValue && newValue > 0
        }
        .sensoryFeedback(.impact(flexibility: .solid), trigger: hasCaptured) { _, captured in
            settings.hapticsEnabled && captured
        }
        .task {
            do {
                cameraSession.prepareForDisplay()
                let startingPosition: AVCaptureDevice.Position = settings.quickSnapUsesFrontCamera ? .front : .back
                try await cameraSession.configure(startingPosition: startingPosition)
                isReady = true
                await runCountdown()
            } catch ImageSourceError.notAuthorized {
                errorMessage = "Camera access is off. Turn it on in Settings to use Quick Snap."
            } catch {
                errorMessage = "The camera is unavailable. Switch media source to keep playing."
            }
        }
        .onDisappear {
            cameraSession.stop()
        }
    }

    /// Drives the shared 100 ms countdown cadence used by the streak/Time Trial timers, then
    /// fires the single automatic capture at zero.
    private func runCountdown() async {
        let end = Date.now.addingTimeInterval(shotDuration)
        while !Task.isCancelled && !hasCaptured {
            try? await Task.sleep(for: .milliseconds(100))
            let timeLeft = end.timeIntervalSinceNow
            if timeLeft <= 0 {
                remaining = 0
                await fireCapture()
                return
            }
            remaining = timeLeft
        }
    }

    private func fireCapture() async {
        guard !hasCaptured else { return }
        hasCaptured = true
        do {
            let image = try await cameraSession.capture()
            cameraSession.stop()
            onCapture(image)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "The shot couldn't be captured. Try again."
        }
    }
}

/// The countdown ring plus its number, reusing the streak timer's under-pressure recoloring:
/// white while there's time, amber as it runs low, red in the final beat.
private struct QuickSnapCountdownOverlay: View {
    let remaining: Double
    let total: Double

    private var progress: Double { total > 0 ? max(0, min(1, remaining / total)) : 0 }
    private var seconds: Int { Int(remaining.rounded(.up)) }

    private var color: Color {
        if remaining > 2 { return .white }
        if remaining > 1 { return .orange }
        return .red
    }

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                Text("\(seconds)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: seconds)
            }
            .frame(width: 120, height: 120)
            .padding(.bottom, 48)

            Text("Tap to snap now — or hold steady until zero")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: .capsule)
                .padding(.bottom, 40)
        }
    }
}

/// Bridges the camera warm-up gap. `AVCaptureSession.startRunning()` returns before the sensor
/// delivers its first frame, so without this the black preview reads as a broken camera rather
/// than one that's still opening.
private struct QuickSnapLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("Starting camera…")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }
}

/// Shown when the camera can't be configured or the capture fails — mirrors the app's
/// `ImageSourceError` messaging and offers a single way back out.
private struct QuickSnapErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Button("Back to Menu", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

#Preview {
    QuickSnapCameraView(shotDuration: 3, onCapture: { _ in }, onCancel: {})
        .environment(SettingsStore())
}
