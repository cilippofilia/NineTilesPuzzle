//
//  SettingsStorePhotoSelectionTests.swift
//  NineTilesPuzzleTests
//
//  Created by Filippo Cilia on 9/27/26.
//

import Testing
@testable import NineTilesPuzzle

@MainActor
@Suite("SettingsStore photo selection")
struct SettingsStorePhotoSelectionTests {
    @Test func defaultsToWholeLibrary() {
        let settings = SettingsStore(defaults: InMemoryPersistenceStore())
        #expect(settings.selectedPhotoIdentifiers.isEmpty)
    }

    @Test func selectionPersistsAcrossInstances() {
        let defaults = InMemoryPersistenceStore()
        SettingsStore(defaults: defaults).setSelectedPhotoIdentifiers(["A/L0/001", "B/L0/001"])

        let restored = SettingsStore(defaults: defaults)
        #expect(restored.selectedPhotoIdentifiers == ["A/L0/001", "B/L0/001"])
    }

    @Test func clearingSelectionPersistsAsWholeLibrary() {
        let defaults = InMemoryPersistenceStore()
        let settings = SettingsStore(defaults: defaults)
        settings.setSelectedPhotoIdentifiers(["A/L0/001"])
        settings.setSelectedPhotoIdentifiers([])

        #expect(SettingsStore(defaults: defaults).selectedPhotoIdentifiers.isEmpty)
    }
}
