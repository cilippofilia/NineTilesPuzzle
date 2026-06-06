//
//  AchievementService.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import Foundation

struct AchievementService {
    // Replace with the URL of your hosted achievements.json
    static let remoteURL = URL(string: "https://example.com/achievements.json")!

    private static var cacheURL: URL {
        URL.cachesDirectory.appending(path: "achievements.json")
    }

    /// Loads achievements from the bundled achievements.json — always available, no network needed.
    static func loadBundle() -> [Achievement] {
        guard
            let url = Bundle.main.url(forResource: "achievements", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let achievements = try? JSONDecoder().decode([Achievement].self, from: data)
        else { return [] }
        return achievements
    }

    /// Reads the most recently cached remote response. Returns nil if no cache exists yet.
    static func loadCached() -> [Achievement]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([Achievement].self, from: data)
    }

    /// Fetches the remote JSON, writes it to the local cache, and returns the decoded achievements.
    static func fetchRemote() async throws -> [Achievement] {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let achievements = try JSONDecoder().decode([Achievement].self, from: data)
        try? data.write(to: cacheURL)
        return achievements
    }
}
