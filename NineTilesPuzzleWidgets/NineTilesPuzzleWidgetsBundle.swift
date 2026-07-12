//
//  NineTilesPuzzleWidgetsBundle.swift
//  NineTilesPuzzleWidgets
//
//  Created by Filippo Cilia on 7/4/26.
//

import SwiftUI
import WidgetKit

@main
struct NineTilesPuzzleWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyChallengeWidget()
        DailyChallengeWidgetAlt()
        PuzzleLiveActivity()
    }
}
