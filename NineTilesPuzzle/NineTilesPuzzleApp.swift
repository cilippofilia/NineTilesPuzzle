//
//  NineTilesPuzzleApp.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import SwiftUI

@main
struct NineTilesPuzzleApp: App {
    @State private var state = PuzzleState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(state)
        }
    }
}
