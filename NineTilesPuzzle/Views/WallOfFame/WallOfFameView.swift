//
//  WallOfFameView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/27/26.
//

import SwiftUI

struct WallOfFameView: View {
    @Environment(WallOfFameStore.self) private var wallOfFameStore
    @Environment(MotionManager.self) private var motionManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var swingEngine = WallOfFameSwingEngine()
    @State private var zoomedCardImage: CGImage?
    @State private var zoomedShareURL: URL?
    @State private var zoomedSlot: WallOfFameSlot?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 20)]

    var body: some View {
        // ZStack lets the zoom overlay escape the ScrollView's coordinate space
        // and cover the full navigation content area (+ safe areas via ignoresSafeArea).
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    boardSection(title: "Best Moves") {
                        ForEach(3...8, id: \.self) { size in
                            cardSlot(for: .bestMoves(gridSize: size))
                        }
                    }
                    boardSection(title: "Fastest Solve") {
                        ForEach(3...8, id: \.self) { size in
                            cardSlot(for: .bestTime(gridSize: size))
                        }
                    }
                    boardSection(title: "Daily Challenge") {
                        cardSlot(for: .dailyBestMoves)
                        cardSlot(for: .dailyBestTime)
                    }
                    boardSection(title: "Streaks") {
                        cardSlot(for: .calendarStreak)
                    }
                    boardSection(title: "Gauntlet Ladder") {
                        ForEach(1...GauntletLadderRules.stageCount, id: \.self) { stage in
                            cardSlot(for: .ladderStage(stage))
                        }
                    }
                }
                .padding(20)
            }
            .background(CorkTextureView().equatable().ignoresSafeArea())

            WallOfFameSwingDriver(engine: swingEngine, motionManager: motionManager)

            if zoomedCardImage != nil && zoomedShareURL != nil {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.3))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let image = zoomedCardImage, zoomedShareURL != nil, let slot = zoomedSlot {
                ZoomedCardOverlay(cardImage: image, slot: slot) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        zoomedCardImage = nil
                        zoomedShareURL = nil
                        zoomedSlot = nil
                    }
                }
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: zoomedCardImage == nil)
        .navigationTitle("Wall of Fame")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = zoomedShareURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url, preview: SharePreview("Record Card")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .onAppear { motionManager.startUpdates() }
        .onDisappear { motionManager.stopUpdates() }
        .onChange(of: scenePhase) { _, newPhase in
            // CMMotionManager suspends delivery while backgrounded but doesn't
            // reset `isDeviceMotionActive`, so without this the tilt effect
            // never resumes after the app returns from the background.
            switch newPhase {
            case .active:
                motionManager.startUpdates()
            case .background:
                motionManager.stopUpdates()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func boardSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundStyle(.white.opacity(0.6))

            LazyVGrid(columns: columns, spacing: 20) {
                content()
            }
        }
    }

    // MARK: - Card slot

    @ViewBuilder
    private func cardSlot(for slot: WallOfFameSlot) -> some View {
        if let image = wallOfFameStore.cardImage(for: slot) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    zoomedCardImage = image
                    zoomedShareURL = wallOfFameStore.fileURL(for: slot)
                    zoomedSlot = slot
                }
            } label: {
                WallOfFamePinnedCard(slot: slot, cardImage: image, engine: swingEngine)
            }
            .buttonStyle(.plain)
        } else {
            WallOfFameEmptySlot(slot: slot)
        }
    }
}

// MARK: - Zoom overlay

private struct ZoomedCardOverlay: View {
    let cardImage: CGImage
    let slot: WallOfFameSlot
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Color.clear.contentShape(.rect)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .buttonStyle(.plain)
        .overlay {
            VStack(spacing: 14) {
                Text(slot.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: .capsule)

                Image(decorative: cardImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 18)
            }
            .padding(.horizontal, 28)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Cork texture

private struct CorkTextureView: View, Equatable {
    // The texture is a fixed, seeded noise pattern with no inputs, so every instance is
    // interchangeable. Conforming to Equatable (always equal) lets `.equatable()` tell
    // SwiftUI to render it exactly once instead of re-running the generation loop each time
    // the parent `WallOfFameView` body re-evaluates (e.g. on every card zoom/unzoom).
    nonisolated static func == (lhs: CorkTextureView, rhs: CorkTextureView) -> Bool { true }

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(red: 0.72, green: 0.56, blue: 0.34))
            )

            var rng = SeededRNG(seed: 42)

            let patchCount = Int(size.width * size.height / 5000)
            for _ in 0..<patchCount {
                let x = rng.next(in: -60.0..<size.width)
                let y = rng.next(in: -60.0..<size.height)
                let w = rng.next(in: 60.0..<180.0)
                let h = rng.next(in: 40.0..<120.0)
                let opacity = rng.next(in: 0.03..<0.08)
                let isDark = rng.next(in: 0.0..<1.0) < 0.55
                let color = isDark
                    ? Color(red: 0.40, green: 0.26, blue: 0.12).opacity(opacity)
                    : Color(red: 0.88, green: 0.76, blue: 0.54).opacity(opacity)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
            }

            let grainCount = Int(size.width * size.height / 55)
            for _ in 0..<grainCount {
                let cx = rng.next(in: 0.0..<size.width)
                let cy = rng.next(in: 0.0..<size.height)
                let w  = rng.next(in: 4.0..<20.0)
                let h  = rng.next(in: 0.8..<3.0)
                let angle = rng.next(in: -Double.pi / 9..<Double.pi / 9)
                let opacity = rng.next(in: 0.09..<0.26)

                var path = Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
                path = path.applying(
                    CGAffineTransform(translationX: -cx, y: -cy)
                        .rotated(by: angle)
                        .translatedBy(x: cx, y: cy)
                )
                context.fill(path, with: .color(Color(red: 0.28, green: 0.16, blue: 0.07).opacity(opacity)))
            }

            let dotCount = Int(size.width * size.height / 18)
            for _ in 0..<dotCount {
                let x = rng.next(in: 0.0..<size.width)
                let y = rng.next(in: 0.0..<size.height)
                let r = rng.next(in: 0.3..<1.4)
                let opacity = rng.next(in: 0.04..<0.15)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 0.22, green: 0.12, blue: 0.04).opacity(opacity))
                )
            }

            let highlightCount = Int(size.width * size.height / 110)
            for _ in 0..<highlightCount {
                let cx = rng.next(in: 0.0..<size.width)
                let cy = rng.next(in: 0.0..<size.height)
                let w  = rng.next(in: 2.0..<9.0)
                let h  = rng.next(in: 0.5..<1.8)
                let angle = rng.next(in: -Double.pi / 8..<Double.pi / 8)
                let opacity = rng.next(in: 0.06..<0.16)

                var path = Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
                path = path.applying(
                    CGAffineTransform(translationX: -cx, y: -cy)
                        .rotated(by: angle)
                        .translatedBy(x: cx, y: cy)
                )
                context.fill(path, with: .color(Color(red: 0.92, green: 0.82, blue: 0.62).opacity(opacity)))
            }
        }
        .drawingGroup()
    }
}

// Minimal LCG PRNG — stable grain across renders.
private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 6364136223846793005 }

    mutating func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func next(in range: Range<Double>) -> Double {
        let t = Double(nextUInt64()) / Double(UInt64.max)
        return range.lowerBound + t * (range.upperBound - range.lowerBound)
    }

    mutating func next(in range: Range<CGFloat>) -> CGFloat {
        CGFloat(next(in: Double(range.lowerBound)..<Double(range.upperBound)))
    }

    mutating func next(in range: Range<Int>) -> Int {
        Int(nextUInt64() % UInt64(range.upperBound - range.lowerBound)) + range.lowerBound
    }
}

#Preview {
    NavigationStack {
        WallOfFameView()
            .environment(WallOfFameStore())
            .environment(MotionManager())
    }
}
