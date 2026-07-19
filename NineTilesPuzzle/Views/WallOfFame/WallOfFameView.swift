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
                    boardSection(title: "Difficulty Highlights") {
                        ForEach(3...8, id: \.self) { size in
                            heroCardSlot(forGridSize: size)
                        }
                    }
                    boardSection(title: "Best Moves") {
                        let canonical = (3...8).map { WallOfFameSlot.bestMoves(gridSize: $0) }
                        ForEach(wallOfFameStore.orderedSlots(section: "bestMoves", canonical: canonical), id: \.self) { slot in
                            curatedCardSlot(for: slot, section: "bestMoves", canonical: canonical)
                        }
                    }
                    boardSection(title: "Fastest Solve") {
                        let canonical = (3...8).map { WallOfFameSlot.bestTime(gridSize: $0) }
                        ForEach(wallOfFameStore.orderedSlots(section: "fastestSolve", canonical: canonical), id: \.self) { slot in
                            curatedCardSlot(for: slot, section: "fastestSolve", canonical: canonical)
                        }
                    }
                    boardSection(title: "Daily Challenge") {
                        let canonical: [WallOfFameSlot] = [.dailyBestMoves, .dailyBestTime]
                        ForEach(wallOfFameStore.orderedSlots(section: "dailyChallenge", canonical: canonical), id: \.self) { slot in
                            curatedCardSlot(for: slot, section: "dailyChallenge", canonical: canonical)
                        }
                    }
                    boardSection(title: "Streaks") {
                        curatedCardSlot(for: .calendarStreak, section: "streaks", canonical: [.calendarStreak])
                    }
                    boardSection(title: "Gauntlet Ladder") {
                        let canonical = (1...GauntletLadderRules.stageCount).map { WallOfFameSlot.ladderStage($0) }
                        ForEach(wallOfFameStore.orderedSlots(section: "gauntletLadder", canonical: canonical), id: \.self) { slot in
                            curatedCardSlot(for: slot, section: "gauntletLadder", canonical: canonical)
                        }
                    }
                }
                .padding(20)
            }
            .background(CorkTextureView().ignoresSafeArea())

            WallOfFameSwingDriver(engine: swingEngine, motionManager: motionManager)

            if zoomedCardImage != nil && zoomedShareURL != nil {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.3))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let image = zoomedCardImage, let url = zoomedShareURL, let slot = zoomedSlot {
                ZoomedCardOverlay(cardImage: image, title: slot.displayTitle, onDismiss: dismissCard) {
                    ShareLink(item: url, preview: SharePreview("Record Card")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
                    // Spring-scale in, but fade straight out: reversing the scale on
                    // removal read as a half-hearted shrink and the spring's long
                    // settling tail made the fade feel laggy.
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .navigationTitle("Wall of Fame")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The nav bar sits transparent over the light cork texture, so the default
            // white inline title washes out. A custom principal title lets us add weight
            // and a drop shadow to keep it legible against the busy background.
            ToolbarItem(placement: .principal) {
                Text("Wall of Fame")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)
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

    /// Fades the zoomed card out with a quick ease — snappier than reversing
    /// the springy zoom-in animation.
    private func dismissCard() {
        withAnimation(.easeOut(duration: 0.18)) {
            zoomedCardImage = nil
            zoomedShareURL = nil
            zoomedSlot = nil
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
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)

            LazyVGrid(columns: columns, spacing: 20) {
                content()
            }
        }
    }

    // MARK: - Hero card slot

    /// The "Difficulty Highlights" section's per-size tile: whichever of `.bestMoves`/`.bestTime` was
    /// captured most recently for `size`, so each difficulty gets one representative photo
    /// instead of the full moves/time breakdown shown further down the board.
    @ViewBuilder
    private func heroCardSlot(forGridSize size: Int) -> some View {
        if let hero = wallOfFameStore.heroSlot(forGridSize: size) {
            cardSlot(for: hero)
        } else {
            WallOfFameEmptySlot(slot: .bestMoves(gridSize: size))
        }
    }

    // MARK: - Card slot

    @ViewBuilder
    private func cardSlot(for slot: WallOfFameSlot) -> some View {
        if let image = wallOfFameStore.cardImage(for: slot) {
            Button {
                // The grid vends display-size thumbnails; the zoomed card wants the
                // capture-resolution PNG, decoded only now that one is actually needed.
                let fullRes = wallOfFameStore.fullResCardImage(for: slot) ?? image
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    zoomedCardImage = fullRes
                    zoomedShareURL = wallOfFameStore.fileURL(for: slot)
                    zoomedSlot = slot
                }
            } label: {
                WallOfFamePinnedCard(slot: slot, cardImage: image, engine: swingEngine)
            }
            .buttonStyle(.plain)
        } else if wallOfFameStore.hasCard(for: slot) {
            // Earned, but its thumbnail is still decoding off the main actor — hold the
            // layout with a blank pinned card until the store's revision bump swaps it in.
            WallOfFameLoadingSlot()
        } else {
            WallOfFameEmptySlot(slot: slot)
        }
    }

    // MARK: - Manual curation (long-press to unpin / rearrange)

    /// Wraps `cardSlot(for:)` with long-press curation for the record sections (not the
    /// derived "Difficulty Highlights" hero cards, which don't have a single stable slot
    /// identity to hide or reorder). A slot never earned renders exactly as `cardSlot(for:)`
    /// would, with no menu — there's nothing yet to unpin or move.
    @ViewBuilder
    private func curatedCardSlot(for slot: WallOfFameSlot, section: String, canonical: [WallOfFameSlot]) -> some View {
        if !wallOfFameStore.hasCard(for: slot) {
            cardSlot(for: slot)
        } else if wallOfFameStore.isHidden(slot) {
            WallOfFameEmptySlot(slot: slot)
                .contextMenu {
                    Button("Re-pin to Wall", systemImage: "pin.fill") {
                        wallOfFameStore.setHidden(slot, hidden: false)
                    }
                }
        } else {
            cardSlot(for: slot)
                .contextMenu {
                    Button("Unpin from Wall", systemImage: "pin.slash", role: .destructive) {
                        wallOfFameStore.setHidden(slot, hidden: true)
                    }
                    moveMenuButtons(for: slot, section: section, canonical: canonical)
                }
        }
    }

    @ViewBuilder
    private func moveMenuButtons(for slot: WallOfFameSlot, section: String, canonical: [WallOfFameSlot]) -> some View {
        let order = wallOfFameStore.orderedSlots(section: section, canonical: canonical)
        if let index = order.firstIndex(of: slot) {
            if index > 0 {
                Button("Move Earlier", systemImage: "arrow.backward") {
                    wallOfFameStore.move(slot, section: section, canonical: canonical, earlier: true)
                }
            }
            if index < order.count - 1 {
                Button("Move Later", systemImage: "arrow.forward") {
                    wallOfFameStore.move(slot, section: section, canonical: canonical, earlier: false)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WallOfFameView()
            .environment(WallOfFameStore())
            .environment(MotionManager())
            .environment(StatsStore())
    }
}
