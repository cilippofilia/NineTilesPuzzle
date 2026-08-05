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

    let tileMoveSoundName = "Classic Click"
    let completionSoundName = "Chime"

    private let clickPlayer: AVAudioPlayer?
    private let completionPlayer: AVAudioPlayer?

    init() {
        let defaults = UserDefaults.standard
        if let legacyValue = defaults.object(forKey: "soundEffectsEnabled") as? Bool {
            isTileMoveEnabled = defaults.object(forKey: "tileMoveSoundEnabled") as? Bool ?? legacyValue
            isCompletionEnabled = defaults.object(forKey: "completionSoundEnabled") as? Bool ?? legacyValue
        } else {
            isTileMoveEnabled = defaults.object(forKey: "tileMoveSoundEnabled") as? Bool ?? true
            isCompletionEnabled = defaults.object(forKey: "completionSoundEnabled") as? Bool ?? true
        }

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

    func playTileClick() {
        guard isTileMoveEnabled else { return }
        play(clickPlayer)
    }

    func playCompletion() {
        guard isCompletionEnabled else { return }
        play(completionPlayer)
    }

    private func play(_ player: AVAudioPlayer?) {
        guard let player else { return }
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
