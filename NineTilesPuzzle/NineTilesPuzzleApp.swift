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
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MenuView()
                    .environment(state)

                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .zIndex(1)
                }
            }
        }
    }
}
