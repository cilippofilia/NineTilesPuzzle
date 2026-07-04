//
//  Int-Formatting-Ext.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/4/26.
//

import Foundation

extension Int {
    /// Formats with the device's locale-preferred grouping separator, e.g. `202'255` on a
    /// Swiss locale or `202,255` on `en_US`.
    var formattedScore: String {
        self.formatted(.number.grouping(.automatic))
    }
}
