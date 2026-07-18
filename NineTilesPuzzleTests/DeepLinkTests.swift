//
//  DeepLinkTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 7/5/26.
//

import Foundation
import Testing
@testable import NineTilesPuzzle

@Suite("DeepLink")
@MainActor
struct DeepLinkTests {
    @Test func roundTripsEveryRoute() throws {
        let links: [DeepLink] = [
            .daily,
            .resume,
            .mode(.slide, gridSize: 4),
            .mode(.chaos, gridSize: nil),
            .mode(.timeTrial, gridSize: 8),
            .paywall
        ]
        for link in links {
            #expect(DeepLink(url: link.url) == link)
        }
    }

    @Test func producesExpectedURLStrings() {
        #expect(DeepLink.daily.url.absoluteString == "ninetilespuzzle://daily")
        #expect(DeepLink.resume.url.absoluteString == "ninetilespuzzle://resume")
        #expect(DeepLink.mode(.slide, gridSize: 4).url.absoluteString == "ninetilespuzzle://mode/slide/4")
        #expect(DeepLink.mode(.fog, gridSize: nil).url.absoluteString == "ninetilespuzzle://mode/fog")
        #expect(DeepLink.paywall.url.absoluteString == "ninetilespuzzle://paywall")
    }

    @Test(arguments: [
        "https://daily",                       // wrong scheme
        "ninetilespuzzle://unknown",           // unknown host
        "ninetilespuzzle://mode",              // mode without a game mode
        "ninetilespuzzle://mode/warp",         // unknown game mode
        "ninetilespuzzle://mode/slide/2",      // size below range
        "ninetilespuzzle://mode/slide/9",      // size above range
        "ninetilespuzzle://mode/slide/x",      // non-numeric size
        "ninetilespuzzle://mode/slide/4/extra", // trailing segment
        "ninetilespuzzle://daily/extra",       // daily takes no path
        "ninetilespuzzle://resume/extra",      // resume takes no path
        "ninetilespuzzle://paywall/extra"      // paywall takes no path
    ])
    func rejectsMalformedURLs(_ raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(DeepLink(url: url) == nil)
    }
}
