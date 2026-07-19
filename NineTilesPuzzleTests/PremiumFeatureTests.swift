//
//  PremiumFeatureTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/18/26.
//

import Testing
@testable import NineTilesPuzzle

@Suite("PremiumFeature")
struct PremiumFeatureTests {
    @Test func onlySlideGameModeIsFree() {
        for mode in GameMode.allCases {
            #expect(mode.isFree == (mode == .slide))
        }
    }

    @Test func onlyRandomAndNumbersMediaSourcesAreFree() {
        let freeSources: Set<MediaSourceType> = [.random, .numbers]
        for source in [MediaSourceType.random, .local, .mixed, .numbers, .camera] {
            #expect(source.isFree == freeSources.contains(source))
        }
    }

    @Test func gameModeFeatureLockingMatchesUnderlyingIsFree() {
        for mode in GameMode.allCases {
            let feature = PremiumFeature.gameMode(mode)
            #expect(feature.isFree == mode.isFree)
            #expect(feature.isLocked(isPremiumUnlocked: false) == !mode.isFree)
            #expect(feature.isLocked(isPremiumUnlocked: true) == false)
        }
    }

    @Test func imageSourceFeatureLockingMatchesUnderlyingIsFree() {
        for source in [MediaSourceType.random, .local, .mixed, .numbers, .camera] {
            let feature = PremiumFeature.imageSource(source)
            #expect(feature.isFree == source.isFree)
            #expect(feature.isLocked(isPremiumUnlocked: false) == !source.isFree)
            #expect(feature.isLocked(isPremiumUnlocked: true) == false)
        }
    }

    @Test func systemAndProgressionFeaturesAreAlwaysPremium() {
        let alwaysPremium: [PremiumFeature] = [
            .liveActivities, .widgets, .wallOfFame, .achievementsArchive, .dailyArchive
        ]
        for feature in alwaysPremium {
            #expect(feature.isFree == false)
            #expect(feature.isLocked(isPremiumUnlocked: false) == true)
            #expect(feature.isLocked(isPremiumUnlocked: true) == false)
        }
    }
}
