//
//  ImageSourceFactory.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 5/25/26.
//

import Foundation

enum ImageSourceFactory {
    static func make() -> any ImageSource {
        RemoteImageSource()
    }
}
