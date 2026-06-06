//
//  SoundService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import AudioToolbox

@MainActor
@Observable
final class SoundService {
    private(set) var isEnabled: Bool

    // 1104 = keyboard click, 1322 = milestone chime
    private let clickSoundID: SystemSoundID = 1104
    private let completionSoundID: SystemSoundID = 1322

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: "soundEffectsEnabled")
    }

    func playTileClick() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(clickSoundID)
    }

    func playCompletion() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(completionSoundID)
    }
}
