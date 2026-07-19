//
//  TimeInterval-Formatting-Ext.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/19/26.
//

import Foundation

extension TimeInterval {
    /// Formats as `m:ss`, e.g. `1:23`.
    var formattedMinutesSeconds: String {
        Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
    }
}
