//
//  ChallengeFilePayload.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    nonisolated static var ninetilesChallenge: UTType {
        UTType(exportedAs: "cilia.filippo.NineTilesPuzzle.challenge")
    }
}

/// Wraps a `FriendChallenge` as a document `ShareLink` can export — unlike
/// `SolvedPuzzleImage`'s `DataRepresentation`, this uses `FileRepresentation` so the share
/// sheet treats it as a `.ntpchallenge` file (works through Messages, Mail, AirDrop, Files),
/// openable later via the app's registered document type, not just a one-shot attachment.
struct ChallengeFilePayload: Transferable {
    let challenge: FriendChallenge

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .ninetilesChallenge) { payload in
            let data = try JSONEncoder().encode(payload.challenge)
            let url = FileManager.default.temporaryDirectory
                .appending(path: payload.challenge.senderName)
                .appendingPathExtension(for: .ninetilesChallenge)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Decodes a `FriendChallenge` from a `.ntpchallenge` file on disk — the counterpart to
/// `ChallengeFilePayload`'s export, used when the app is opened via a received file
/// (Messages attachment tap, AirDrop accept, Files "Open in Nine Tiles Puzzle").
enum ChallengeFileCoder {
    static func decode(fileAt url: URL) -> FriendChallenge? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let challenge = try? JSONDecoder().decode(FriendChallenge.self, from: data),
              challenge.formatVersion <= FriendChallenge.currentFormatVersion
        else { return nil }
        return challenge
    }
}
