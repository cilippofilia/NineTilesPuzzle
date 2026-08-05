//
//  SoundService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import AVFoundation

@MainActor
@Observable
final class SoundService {
    private(set) var isTileMoveEnabled: Bool
    private(set) var isCompletionEnabled: Bool
    /// Per-sound volume, independent of `FeedbackIntensity`'s shared scale — the two
    /// multiply together at playback time.
    private(set) var tileMoveVolume: Double
    private(set) var completionVolume: Double

    let tileMoveSoundName = "Classic Click"
    let completionSoundName = "Chime"

    private let clickPlayer: AVAudioPlayer?
    private let completionPlayer: AVAudioPlayer?
    /// Read lazily rather than injected as a stored `FeedbackIntensity`, mirroring
    /// `StoreManager`'s `debugOverride` closure — keeps `SoundService` decoupled from
    /// `SettingsStore` while still tracking the live "Feedback Intensity" setting.
    private let volumeScale: () -> Double

    init(volumeScale: @escaping () -> Double = { 1.0 }) {
        self.volumeScale = volumeScale
        let defaults = UserDefaults.standard
        if let legacyValue = defaults.object(forKey: "soundEffectsEnabled") as? Bool {
            isTileMoveEnabled = defaults.object(forKey: "tileMoveSoundEnabled") as? Bool ?? legacyValue
            isCompletionEnabled = defaults.object(forKey: "completionSoundEnabled") as? Bool ?? legacyValue
        } else {
            isTileMoveEnabled = defaults.object(forKey: "tileMoveSoundEnabled") as? Bool ?? true
            isCompletionEnabled = defaults.object(forKey: "completionSoundEnabled") as? Bool ?? true
        }
        tileMoveVolume = defaults.object(forKey: "tileMoveVolume") as? Double ?? 1.0
        completionVolume = defaults.object(forKey: "completionVolume") as? Double ?? 1.0

        // .ambient respects the ring/silent switch and the system volume.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)

        clickPlayer = Self.loadPlayer(named: "TileClick", withExtension: "wav")
        completionPlayer = Self.loadPlayer(named: "Completion", withExtension: "wav")
    }

    func setTileMoveEnabled(_ value: Bool) {
        isTileMoveEnabled = value
        UserDefaults.standard.set(value, forKey: "tileMoveSoundEnabled")
    }

    func setCompletionEnabled(_ value: Bool) {
        isCompletionEnabled = value
        UserDefaults.standard.set(value, forKey: "completionSoundEnabled")
    }

    func setTileMoveVolume(_ value: Double) {
        tileMoveVolume = value
        UserDefaults.standard.set(value, forKey: "tileMoveVolume")
    }

    func setCompletionVolume(_ value: Double) {
        completionVolume = value
        UserDefaults.standard.set(value, forKey: "completionVolume")
    }

    func playTileClick() {
        guard isTileMoveEnabled else { return }
        play(clickPlayer, volume: tileMoveVolume)
    }

    func playCompletion() {
        guard isCompletionEnabled else { return }
        play(completionPlayer, volume: completionVolume)
    }

    private func play(_ player: AVAudioPlayer?, volume: Double) {
        guard let player else { return }
        let resolvedVolume = Float(volumeScale() * volume)
        guard resolvedVolume > 0 else { return }
        player.volume = resolvedVolume
        player.currentTime = 0
        player.play()
    }

    private static func loadPlayer(named name: String, withExtension extension: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: `extension`) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}
