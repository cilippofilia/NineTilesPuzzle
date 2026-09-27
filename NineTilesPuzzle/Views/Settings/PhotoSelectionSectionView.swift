//
//  PhotoSelectionSectionView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 9/27/26.
//

import PhotosUI
import SwiftUI

/// Lets a player who granted full library access narrow From Photos / Mixed down to a
/// hand-picked set of photos. Limited-access players don't need it — their shared set
/// already is the pool, managed in the system Settings.
struct PhotoSelectionSectionView: View {
    @Environment(SettingsStore.self) private var settings

    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        Section {
            // `.shared()` is what makes the picker hand back `itemIdentifier`s, which map
            // straight onto `PHAsset` local identifiers for `PhotoLibraryImageSource`.
            PhotosPicker(selection: $pickerItems, matching: .images, photoLibrary: .shared()) {
                LabeledContent("Choose Photos") {
                    if settings.selectedPhotoIdentifiers.isEmpty {
                        Text("Whole Library")
                    } else {
                        Text("^[\(settings.selectedPhotoIdentifiers.count) photo](inflect: true)")
                    }
                }
            }

            if !settings.selectedPhotoIdentifiers.isEmpty {
                Button("Use Whole Library", role: .destructive) {
                    pickerItems = []
                }
            }
        } header: {
            Text("Photo Pool")
        } footer: {
            Text("Pick the photos to puzzle with. With none picked, a random photo from your whole library is used.")
        }
        .onAppear {
            // Seeding the picker with the saved selection means reopening it shows the
            // current picks checked, so it edits the set rather than replacing it.
            pickerItems = settings.selectedPhotoIdentifiers.map { PhotosPickerItem(itemIdentifier: $0) }
        }
        .onChange(of: pickerItems) { _, newItems in
            settings.setSelectedPhotoIdentifiers(newItems.compactMap(\.itemIdentifier))
        }
    }
}

#Preview {
    List {
        PhotoSelectionSectionView()
    }
    .environment(SettingsStore())
}
