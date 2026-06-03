//
//  PhotoSourcePickerView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/3/26.
//

import Photos
import SwiftUI
import UIKit

struct PhotoSourcePickerView: View {
    @Environment(PuzzleState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        List {
            Button {
                state.setImageSourceType(.random)
                dismiss()
            } label: {
                LabeledContent {
                    if state.imageSourceType == .random {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Internet")
                        Text("A new image from the internet each game")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)

            Button {
                state.setImageSourceType(.local)
                Task {
                    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    authStatus = status
                }
                dismiss()
            } label: {
                LabeledContent {
                    if state.imageSourceType == .local {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("From Photos")
                        Text("A random photo from your library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)

            Button {
                state.setImageSourceType(.mixed)
                Task {
                    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    authStatus = status
                }
                dismiss()
            } label: {
                LabeledContent {
                    if state.imageSourceType == .mixed {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Mixed")
                        Text("Randomly picks internet or your library each game")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)

            if authStatus == .limited {
                Section {
                    Button("Update Photo Access in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .foregroundStyle(.tint)
                } footer: {
                    Text("Only a limited selection of photos is available to this app.")
                }
            }
        }
        .navigationTitle("Photo Source")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
    }
}

#Preview {
    NavigationStack {
        PhotoSourcePickerView()
            .environment(PuzzleState())
    }
}
