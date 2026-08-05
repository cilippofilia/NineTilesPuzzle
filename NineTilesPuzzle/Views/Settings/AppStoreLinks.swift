//
//  AppStoreLinks.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 8/5/26.
//

import Foundation

enum AppStoreLinks {
    private static let appID = "6776386637"
    private static let supportEmail = "cilia.filippo@icloud.com"

    static let productURL = URL(string: "https://apps.apple.com/app/id\(appID)")!
    static let reviewURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")!

    static func mailURL(for option: ContactOption) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: option.subject),
            URLQueryItem(name: "body", value: option.body)
        ]
        return components.url
    }
}
