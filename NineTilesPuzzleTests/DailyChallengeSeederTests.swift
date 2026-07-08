//
//  DailyChallengeSeederTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/5/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("DailyChallengeSeeder")
@MainActor
struct DailyChallengeSeederTests {
    /// A fixed date (July 5, 2026, mid-day) so results are reproducible run to run.
    private var referenceDate: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 12))!
    }

    private func day(offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: referenceDate)!
    }

    // MARK: - Determinism (what the widget relies on to precompute midnight entries)

    @Test func sameDayProducesIdenticalIdentity() {
        // Morning and evening of the same calendar day must agree — the widget computes
        // the day's grid/mode independently of when the app last did.
        let morning = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 0, minute: 1))!
        let evening = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 23, minute: 59))!

        #expect(DailyChallengeSeeder.seed(for: morning) == DailyChallengeSeeder.seed(for: evening))
        #expect(DailyChallengeSeeder.gridSize(for: morning) == DailyChallengeSeeder.gridSize(for: evening))
        #expect(DailyChallengeSeeder.gameMode(for: morning) == DailyChallengeSeeder.gameMode(for: evening))
        #expect(DailyChallengeSeeder.imageURL(for: morning) == DailyChallengeSeeder.imageURL(for: evening))
    }

    @Test func identityStaysWithinAdvertisedPools() {
        for offset in 0..<60 {
            let date = day(offset: offset)
            let size = DailyChallengeSeeder.gridSize(for: date)
            let mode = DailyChallengeSeeder.gameMode(for: date)
            #expect(DailyChallengeSeeder.availableGridSizes.contains(size))
            #expect(DailyChallengeSeeder.availableGameModes.contains(mode))
        }
    }

    @Test func identityVariesAcrossDays() {
        // Not a distribution test — just proof the pickers aren't stuck on one value.
        let sizes = Set((0..<60).map { DailyChallengeSeeder.gridSize(for: day(offset: $0)) })
        let modes = Set((0..<60).map { DailyChallengeSeeder.gameMode(for: day(offset: $0)) })
        #expect(sizes.count > 1)
        #expect(modes.count > 1)
    }

    @Test func imageURLUsesZeroPaddedDaySeed() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        let expected = "https://picsum.photos/seed/ntp-2026-03-09/1024/1024"
        #expect(DailyChallengeSeeder.imageURL(for: date).absoluteString == expected)
    }
}
