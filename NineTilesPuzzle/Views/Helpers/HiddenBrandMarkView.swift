//
//  HiddenBrandMarkView.swift
//  NineTilesPuzzle
//

import SwiftUI

/// Sits directly behind the Dynamic Island. The resting pill is excluded from
/// screenshot capture, so this stays invisible during normal use but appears
/// in screenshots taken while the island is idle. Sized to stay within the
/// pill's footprint — may need on-device tuning per the plan's verification note.
///
/// Notch devices have no equivalent capsule to hide behind — the notch is a fixed
/// display cutout, not a software-rendered overlay — so this renders nothing there
/// rather than leaving a permanently visible logo near the top of the screen.
struct HiddenBrandMarkView: View {
    // The island is a capsule (~126×37.33pt), whose fully rounded ends (radius =
    // height/2 ≈ 18.7pt) eat into the outer edges, leaving a flat, full-height middle
    // strip theoretically only ~88pt — but on-device screenshots show the live island
    // rendering wider than that, so safeContentWidth has been pushed past 88pt to match.
    // If corners start poking past the curve on a given device, pull this back down.
    // Sizes are fixed rather than Dynamic Type on purpose: this has to track a hardware
    // silhouette, not adapt to text size.
    private let safeContentWidth: CGFloat = 94
    // The top safe-area inset on every Dynamic Island device is 59pt, with the status
    // bar row (time, signal, battery) vertically centered within it. The island pill
    // itself is centered in that same 59pt band, not flush to the physical top edge —
    // so framing content to only the pill's own height and ignoring the safe area pins
    // it ~11pt too high, out of line with the time/battery text either side of it.
    // Matching this frame height instead centers our content in the same band.
    private let statusBarHeight: CGFloat = 59
    // Every notch's top safe-area inset (44–51pt across mini/standard/Plus models) is
    // below this, while the Dynamic Island's is 59pt — so this threshold tells them
    // apart at runtime without a hardcoded device/model list.
    private let dynamicIslandInsetThreshold: CGFloat = 55

    @State private var hasDynamicIsland = false

    private var puzzleGradient: LinearGradient {
        LinearGradient(colors: [.red, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
    }

    var body: some View {
        Group {
            if hasDynamicIsland {
                HStack(spacing: 5) {
                    Image(systemName: "puzzlepiece.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                        .rotationEffect(.degrees(-45))
                        .foregroundStyle(puzzleGradient)

                    Text("Nine Tiles")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: safeContentWidth, height: statusBarHeight)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.top
        } action: { topInset in
            hasDynamicIsland = topInset >= dynamicIslandInsetThreshold
        }
    }
}

#Preview {
    ZStack(alignment: .top) {
        Color.black.ignoresSafeArea()
        HiddenBrandMarkView()
    }
}
