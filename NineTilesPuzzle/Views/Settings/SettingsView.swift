//
//  SettingsView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 6/6/26.
//

import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(GameSession.self) private var session
    @Environment(StatsStore.self) private var statsStore
    @Environment(SettingsStore.self) private var settings
    @Environment(DailyChallengeStore.self) private var dailyStore
    @Environment(PowerUpStore.self) private var powerUpStore
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showResetStatsAlert = false
    @State private var showResetSettingsAlert = false
    @State private var showDebugOverlayAlert = false
    @State private var showContactOptions = false
    @State private var paywallContext: PaywallContext?
    @State private var showManageSubscriptions = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !store.isPremiumUnlocked {
                        Label {
                            Text("VIP Unlocked")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                        }

                        if store.hasActiveSubscription {
                            Button("Manage Subscription") { showManageSubscriptions = true }
                        }

                        NavigationLink {
                            WidgetsGuideView()
                        } label: {
                            Label {
                                Text("How to Add Widgets")
                            } icon: {
                                Image(systemName: "widget.small.badge.plus")
                                    .foregroundStyle(.white)
                            }
                        }

                        if settings.powerUpsEnabled {
                            NavigationLink {
                                PowerUpsGuideView()
                            } label: {
                                Label {
                                    Text("How to Use Power-ups")
                                } icon: {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    } else {
                        Button {
                            paywallContext = .general
                        } label: {
                            Label {
                                Text("Unlock Nine Tiles Puzzle VIP")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "crown.fill")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    if !store.isPremiumUnlocked {
                        Text("Unlock every game mode, personalize puzzles with your own photos, and get the full experience.")
                    }
                }

                #if DEBUG
                Section {
                    Toggle("Show debug tools", isOn: Binding(
                        get: { settings.debugOverlayEnabled },
                        set: { newValue in
                            if newValue {
                                showDebugOverlayAlert = true
                            } else {
                                settings.setDebugOverlayEnabled(false)
                            }
                        }
                    ))
                } header: {
                    Text("Dev Tools")
                } footer: {
                    Text("This feature is for development testing only and is not intended for production use.")
                }

                if settings.debugOverlayEnabled {
                    Section {
                        Toggle("Force VIP Unlocked", isOn: Binding(
                            get: { settings.debugForcePremiumUnlocked },
                            set: { newValue in
                                settings.setDebugForcePremiumUnlocked(newValue)
                                store.syncWidgetEntitlementForDebugOverride()
                            }
                        ))

                        Button(settings.debugForcePremiumRemoved ? "Restore VIP Lifetime Access" : "Remove VIP Lifetime Access") {
                            settings.setDebugForcePremiumRemoved(!settings.debugForcePremiumRemoved)
                            store.syncWidgetEntitlementForDebugOverride()
                        }
                    } header: {
                        Text("Subscription")
                    } footer: {
                        Text("Force VIP Unlocked simulates an active VIP entitlement without a sandbox purchase, so premium-gated features can be tested. Remove VIP Lifetime Access suppresses a real (or forced) entitlement so the non-VIP experience can be tested without deleting the transaction in Xcode. Both are off by default.")
                    }

                    Section {
                        Stepper(
                            "Day offset: \(dailyStore.debugDayOffset > 0 ? "+" : "")\(dailyStore.debugDayOffset)",
                            value: Binding(
                                get: { dailyStore.debugDayOffset },
                                set: { dailyStore.setDebugDayOffset($0) }
                            )
                        )

                        Button("Reset Today's Completion") {
                            dailyStore.resetCompletionForDebug()
                            session.syncWidgetsAfterReset()
                        }
                    } header: {
                        Text("Daily Challenge")
                    } footer: {
                        Text("Offset shifts the puzzle date so you can test different modes and grid sizes. Reset clears today's completion so the Play button reappears.")
                    }

                    Section {
                        Toggle("Enable Power-ups", isOn: Binding(
                            get: { settings.powerUpsEnabled },
                            set: { settings.setPowerUpsEnabled($0) }
                        ))

                        Toggle("Infinite Power-ups", isOn: Binding(
                            get: { settings.debugInfinitePowerUps },
                            set: { settings.setDebugInfinitePowerUps($0) }
                        ))

                        Stepper(
                            "Peek duration: \(Int(settings.peekDuration))s",
                            value: Binding(
                                get: { settings.peekDuration },
                                set: { settings.setPeekDuration($0) }
                            ),
                            in: 1...15
                        )

                        Stepper(
                            "Streak milestone: every \(settings.streakMilestoneInterval)",
                            value: Binding(
                                get: { settings.streakMilestoneInterval },
                                set: { settings.setStreakMilestoneInterval($0) }
                            ),
                            in: 1...20
                        )

                        Button("Refill Power-ups (3 each)") {
                            powerUpStore.resetToDefaults()
                        }
                    } header: {
                        Text("Power-ups")
                    } footer: {
                        Text("Enable Power-ups turns on the power-up system in-game — it's off by default while still being tuned. Infinite Power-ups lets every power-up be used without spending inventory. The steppers tune how long a Peek/Hint shows and how often a streak milestone earns a power-up. Refill tops every power-up back up to 3 for testing.")
                    }

                    Section {
                        Toggle("Enable Challenge Friends", isOn: Binding(
                            get: { settings.challengeFriendsEnabled },
                            set: { settings.setChallengeFriendsEnabled($0) }
                        ))

                        if settings.challengeFriendsEnabled {
                            TextField("Your Game tag", text: Binding(
                                get: { settings.senderDisplayName },
                                set: { settings.setSenderDisplayName($0) }
                            ))
                        }
                    } header: {
                        Text("Challenge Friends")
                    } footer: {
                        Text("Send a friend a seeded puzzle and compare move counts, by file share or nearby device — it's off by default while it's still unverified on real hardware. Your Game tag is shown to friends when you send them a challenge.")
                    }
                }
                #endif

                Section("Game Settings") {
                    NavigationLink("Gameplay") {
                        GameplaySettingsView()
                    }

                    NavigationLink("Notifications") {
                        NotificationsSettingsView()
                    }

                    NavigationLink("Audio & Haptics") {
                        AudioHapticsSettingsView()
                    }
                }

                if gameCenterService.isAuthenticated {
                    Section("Game Center") {
                        Button("Open Game Center") {
                            gameCenterService.showDashboard()
                        }
                    }
                }

                Section {
                    Button {
                        openURL(AppStoreLinks.reviewURL)
                    } label: {
                        Label {
                            Text("Rate the app")
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showContactOptions = true
                    } label: {
                        Label {
                            Text("Contact the developer")
                        } icon: {
                            Image(systemName: "envelope")
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Select an option", isPresented: $showContactOptions, titleVisibility: .visible) {
                        ForEach(ContactOption.allCases) { option in
                            Button(option.title) {
                                if let mailURL = AppStoreLinks.mailURL(for: option) {
                                    openURL(mailURL)
                                }
                            }
                        }
                    }

                    ShareLink(item: AppStoreLinks.productURL) {
                        Label {
                            Text("Share the app")
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Contacts")
                } footer: {
                    Text("App Version: \(Bundle.main.appVersionNumber) (\(Bundle.main.appBuildNumber))")
                }

                Section {
                    Button("Reset Stats", role: .destructive) {
                        showResetStatsAlert = true
                    }

                    Button("Reset Settings", role: .destructive) {
                        showResetSettingsAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset Stats?", isPresented: $showResetStatsAlert) {
                Button("Reset", role: .destructive) {
                    statsStore.resetStats()
                    session.syncWidgetsAfterReset()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current streak, best streak, move counter, personal bests, and games played will be cleared.")
            }
            .alert("Reset Settings?", isPresented: $showResetSettingsAlert) {
                Button("Reset", role: .destructive) {
                    session.resetConfiguration()
                    settings.resetSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Media source, preview time, streak countdown, Quick Snap timer, and difficulty will be restored to their default values.")
            }
            .alert("Turn On Tile Indices?", isPresented: $showDebugOverlayAlert) {
                Button("Turn On") { settings.setDebugOverlayEnabled(true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("While enabled, your streak, best moves, games played, and achievements won't be updated. Turn this off to resume tracking your progress.")
            }
        }
        .paywallSheet(context: $paywallContext)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    let stats = StatsStore()
    let settings = SettingsStore()
    let achievements = AchievementsStore()
    let daily = DailyChallengeStore()
    let powerUps = PowerUpStore()
//    Color.clear
//        .sheet(isPresented: .constant(true)) {
            return SettingsView()
                .environment(GameSession(statsStore: stats, achievementsStore: achievements, settingsStore: settings, dailyChallengeStore: daily, powerUpStore: powerUps, challengeStore: ChallengeStore()))
                .environment(stats)
                .environment(settings)
                .environment(daily)
                .environment(powerUps)
                .environment(SoundService())
                .environment(GameCenterService())
                .environment(DailyReminderService())
                .environment(StoreManager())
//        }
}
