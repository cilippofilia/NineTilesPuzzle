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

private extension String {
    /// `senderName`/`responderName` are free-text, so they can contain path separators — strip
    /// those before the string becomes a filename component, and fall back to a generic label
    /// if nothing usable is left.
    nonisolated var sanitizedForFilename: String {
        let cleaned = components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Player" : cleaned
    }
}

/// The envelope every `.ntpchallenge` file (and nearby result reply) actually carries: either a
/// fresh invite or the reply to one already played. One shared file type keeps both directions
/// openable through the same document-type registration and `.onOpenURL` handler.
nonisolated enum ChallengePayload: Codable, Sendable {
    case invite(FriendChallenge)
    case result(ChallengeResult)
}

/// Wraps a `FriendChallenge` as a document `ShareLink` can export — unlike
/// `SolvedPuzzleImage`'s `DataRepresentation`, this uses `FileRepresentation` so the share
/// sheet treats it as a `.ntpchallenge` file (works through Messages, Mail, AirDrop, Files),
/// openable later via the app's registered document type, not just a one-shot attachment.
struct ChallengeFilePayload: Transferable {
    let challenge: FriendChallenge

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .ninetilesChallenge) { payload in
            let data = try JSONEncoder().encode(ChallengePayload.invite(payload.challenge))
            let url = FileManager.default.temporaryDirectory
                .appending(path: "\(payload.challenge.senderName.sanitizedForFilename)'s Challenge")
                .appendingPathExtension(for: .ninetilesChallenge)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Wraps a `ChallengeResult` reply as a document `ShareLink` can export — the counterpart to
/// `ChallengeFilePayload`, sent back once a received challenge has been played.
struct ChallengeResultFilePayload: Transferable {
    let result: ChallengeResult

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .ninetilesChallenge) { payload in
            let data = try JSONEncoder().encode(ChallengePayload.result(payload.result))
            let url = FileManager.default.temporaryDirectory
                .appending(path: "\(payload.result.responderName.sanitizedForFilename)'s Result")
                .appendingPathExtension(for: .ninetilesChallenge)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Decodes a `ChallengePayload` from a `.ntpchallenge` file on disk — the counterpart to
/// `ChallengeFilePayload`/`ChallengeResultFilePayload`'s export, used when the app is opened via
/// a received file (Messages attachment tap, AirDrop accept, Files "Open in Nine Tiles Puzzle").
enum ChallengeFileCoder {
    static func decode(fileAt url: URL) -> ChallengePayload? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(ChallengePayload.self, from: data)
        else { return nil }
        if case .invite(let challenge) = payload, challenge.formatVersion > FriendChallenge.currentFormatVersion {
            return nil
        }
        return payload
    }
}
