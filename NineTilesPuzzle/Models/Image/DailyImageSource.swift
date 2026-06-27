//
//  DailyImageSource.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

/// Fetches today's seeded picsum image for the Daily Challenge.
/// The same calendar date always returns the same image, so every player sees
/// an identical puzzle. Uses the system URL cache (unlike `RemoteImageSource`
/// which bypasses it), so the image is fetched at most once per day.
struct DailyImageSource: ImageSource {
    let date: Date

    func fetchImage() async throws -> CGImage {
        let url = DailyChallengeSeeder.imageURL(for: date)
        let (data, _) = try await URLSession.shared.data(from: url)
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ImageSourceError.invalidImageData
        }
        return image
    }
}
