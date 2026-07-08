//
//  ChallengeInviteView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/8/26.
//

import SwiftUI

/// Shown when a Challenge Friends puzzle arrives (file opened or Multipeer receipt) — a
/// "beat N moves" preview before committing to play it. Presented as a `fullScreenCover`
/// from `MenuView` since a received challenge can interrupt the app at any navigation depth.
struct ChallengeInviteView: View {
    let challenge: FriendChallenge
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let preview = ChallengeImageCodec.decode(challenge.imageData) {
                    Image(decorative: preview, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(radius: 8)
                }

                VStack(spacing: 6) {
                    Text("\(challenge.senderName) challenged you!")
                        .font(.title2.bold())

                    Text("\(challenge.gameMode.title) · \(challenge.gridSize)×\(challenge.gridSize)")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 24) {
                    ChallengeTargetStatView(icon: "arrow.left.arrow.right", value: challenge.senderMoves.formatted(), label: "Moves")
                    ChallengeTargetStatView(
                        icon: "clock",
                        value: Duration.seconds(challenge.senderTime).formatted(.time(pattern: .minuteSecond)),
                        label: "Time"
                    )
                }
                .padding()
                .background(.quaternary, in: .rect(cornerRadius: 16))

                Text("Beat their score to win!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Accept Challenge", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("Not Now", role: .cancel, action: onDecline)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ChallengeTargetStatView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Label(value, systemImage: icon)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let imageData: Data = {
        let context = CGContext(
            data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        return ChallengeImageCodec.encode(context.makeImage()!)!
    }()

    ChallengeInviteView(
        challenge: FriendChallenge(
            senderName: "Alex", gameMode: .swap, gridSize: 4, seed: 1,
            imageData: imageData, senderMoves: 28, senderTime: 63
        ),
        onAccept: {},
        onDecline: {}
    )
}
