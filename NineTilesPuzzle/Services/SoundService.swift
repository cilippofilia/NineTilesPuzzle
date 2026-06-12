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
    private(set) var isEnabled: Bool

    private let clickPlayer: AVAudioPlayer?
    private let completionPlayer: AVAudioPlayer?

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true

        // .ambient respects the ring/silent switch and the system volume.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)

        clickPlayer = Self.loadPlayer(named: "TileClick", withExtension: "wav")
        completionPlayer = Self.loadPlayer(named: "Completion", withExtension: "wav")
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: "soundEffectsEnabled")
    }

    func playTileClick() {
        guard isEnabled else { return }
        play(clickPlayer)
    }

    func playCompletion() {
        guard isEnabled else { return }
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
