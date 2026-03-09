//
//  ContentView.swift
//  TestApp
//
//  Created by Alex Bradshaw on 25.12.25.
//

import SwiftUI
import Combine
import GoogleMobileAds
import UIKit
import Foundation
import AVFoundation
import AudioToolbox
import QuartzCore
import UserMessagingPlatform
import FirebaseAuth
import FirebaseFirestore


// Simple app links container to avoid undefined symbol errors
// Replace the URL below with your actual privacy policy URL.
struct AppLinks {
    static let privacyPolicy: URL = URL(string: "https://doc-hosting.flycricket.io/pp/8d89576a-2697-4a05-8b63-fcef73a1c7e0/privacy")!
}




private extension UIApplication {
    var activeKeyWindow: UIWindow? {
        // Prefer the foreground active scene's key window
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private struct ActiveSheetsModifier: ViewModifier {
    @Binding var activeSheet: ContentView.ActiveSheet?
    @Binding var sheetSection: ContentView.SettingsSection
    var money: Binding<Double>
    var coins: Binding<Double>
    @Binding var isStreakProtected: Bool
    @Binding var currentStreak: Double
    @Binding var streakMultiplier: Double
    @Binding var hasUsedProtectionForCurrentStreak: Bool
    @Binding var glowMultiplierRoulette: Bool
    @Binding var glowNumbersRoulette: Bool
    @Binding var roulette2OriginalMoney: Double
    var playRewardSound: () -> Void
    var playLossSound: () -> Void
    var applyWin: (Binding<Double>, Double, Bool) -> Void
    var applyLoss: (Binding<Double>, Double, Bool) -> Void
    var animateValue: (Binding<Double>, Double, Bool) -> Void
    var recomputeStats: () -> Void
    let settingsContentBuilder: () -> AnyView

    func body(content: Content) -> some View {
        content
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .roulette:
                    ContentView.RouletteWheelView(isPresented: Binding(get: { activeSheet == .roulette }, set: { newValue in if !newValue { activeSheet = nil } })) { _ in }
                case .roulette2:
                    ContentView.RouletteNumberWheelView(isPresented: Binding(get: { activeSheet == .roulette2 }, set: { newValue in if !newValue { activeSheet = nil } })) { _,_,_ in } onCommitPick: { _ in }
                case .settings:
                    NavigationStack {
                        SettingsSheetHost(section: $sheetSection, contentBuilder: settingsContentBuilder)
                            
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Close") { activeSheet = nil }
                                }
                            }
                    }
                case .addFriend:
                    AddFriendsView()
                }
            }
    }
}

// Host to present settings content with the parent's binding
private struct SettingsSheetHost: View {
    @Binding var section: ContentView.SettingsSection
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var economy: EconomyStore
    // The parent passes a closure that renders settings content using the parent's state.
    let contentBuilder: () -> AnyView
    var body: some View {
        contentBuilder()
    }
}


struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            #if DEBUG
            print("[Banner] Did receive ad")
            #endif
        }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[Banner] Failed to load: \(error.localizedDescription)")
            #endif
        }
        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            #if DEBUG
            print("banner ad: impression recorded")
            #endif
        }
        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            #if DEBUG
            print("[Banner] Click recorded")
            #endif
        }
        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            #if DEBUG
            print("[Banner] Will present screen")
            #endif
        }
        func bannerViewWillDismissScreen(_ bannerView: BannerView) {
            #if DEBUG
            print("[Banner] Will dismiss screen")
            #endif
        }
        func bannerViewDidDismissScreen(_ bannerView: BannerView) {
            #if DEBUG
            print("[Banner] Did dismiss screen")
            #endif
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.activeKeyWindow?.rootViewController ?? UIViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // No-op
    }
}



struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.80 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct PNGButtonBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Keep the label filling horizontally, but make the background taller
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
            .padding(.vertical, -60)
            .contentShape(Rectangle())
            // Counteract the extra height so inter-button spacing doesn't grow
            // Previously min/max height was 52; now it's 64 (+12). Apply -6 on top and bottom.
            .buttonStyle(.plain)
    }
}

extension View {
    func pngButtonStyle() -> some View {
        self.modifier(PNGButtonBackground())
    }
}

struct SectionRow: View {
    let icon: String
    let title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .foregroundColor(.primary)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct TimerBadge: View {
    @Binding var timeRemaining: Int
    @EnvironmentObject var economy: EconomyStore
    var reward: Double = 100.0
    @State private var flash = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("$\(reward, specifier: "%.0f") will be added in:")
                .font(.caption2)
                .foregroundColor(.blue)
            
            Text(formatTime(timeRemaining))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.green)
                .scaleEffect(flash ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: flash)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding(12)
        .onChange(of: timeRemaining) {
            if timeRemaining == 3 * 60 * 60 {
                flash = true
                Task { await economy.addCoins(reward) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    flash = false
                }
            }
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}


struct ContentView: View {
    
    enum ActiveSheet: Identifiable {
        case roulette
        case roulette2
        case settings
        case addFriend
        var id: String {
            switch self {
            case .roulette: return "roulette"
            case .roulette2: return "roulette2"
            case .settings: return "settings"
            case .addFriend: return "addFriend"
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet? = nil
    
    @State private var uiCoins: Double = 0
    @State private var uiMoney: Double = 0
    
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var auth: AuthManager
    
    @EnvironmentObject var economy: EconomyStore
    
    // Added environment object for upgrades store
    @EnvironmentObject var upgrades: UpgradesStore
    
    private var uid: String {
        Auth.auth().currentUser?.uid ?? "guest"
    }

    // Inserted bindings for economy values
    private var coinsBinding: Binding<Double> {
        Binding(
            get: { economy.coins },
            set: { newValue in
                economy.coins = newValue
            }
        )
    }

    private var moneyBinding: Binding<Double> {
        Binding(
            get: { economy.money },
            set: { newValue in
                economy.money = newValue
            }
        )
    }

    private var netWorth: Double {
        economy.coins + economy.money
    }
    
    @State private var showingOfflineIncomePopup = false
    @State private var offlineIncomeAmount: Double = 0
    
    @State private var pendingPassiveIncome: Double = 0
    @State private var lastActiveDate: Date = Date()
    @State private var coinsPerSecond: Double = 0
    
    @State private var bet: Double = 10.0
    @State private var showAlert = false
    @State private var showingAmountPopup: Bool = false
    @State private var popupMode: PopupMode = .add
    @State private var amountText: String = ""
    @StateObject private var rewardedAdManager = RewardedAdManager()
    @State private var rouletteResultMultiplier: Double? = nil
    @State private var streakMultiplier: Double = 1.0
    @State private var isAnimatingValue = false
    
    @State private var currentStreak: Double = 1.0
    @State private var lastTotals: (coins: Double, money: Double) = (0.0, 0.0)
    
    @State private var roulette2OriginalMoney: Double = 0.0
    
    @State private var timeRemaining = 3*60*60
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var glowDoubleOrNothing = false
    @State private var glowTenX = false
    @State private var glowTwoPercent = false
    @State private var glowTenPercent = false
    @State private var glowOnePercent = false
    @State private var glowFiftyPercent = false
    @State private var glowMultiplierRoulette = false
    @State private var glowNumbersRoulette = false
    @State private var showingHighRiskConfirm: Bool = false
    @State private var showingLotteryConfirm: Bool = false
    @State private var showingHighRollerConfirm: Bool = false
    @State private var showingSuperHighRollerConfirm: Bool = false
    @State private var showingDollarForTwoConfirm: Bool = false
    
    @State private var isAnimatingCoinsIncrease: Bool = false
    @State private var isAnimatingCoinsDecrease: Bool = false
    @State private var isAnimatingMoneyIncrease: Bool = false
    @State private var isAnimatingMoneyDecrease: Bool = false
    
    @State private var isStreakProtected: Bool = false
    @State private var hasUsedProtectionForCurrentStreak: Bool = false
    @State private var showingProtectionConfirm: Bool = false
    
    @State private var adCooldownRemaining: Int = 0 // seconds
    @State private var isRewardAdReady: Bool = false
    
    @State private var canRequestAds: Bool = false
    @State private var hasAttemptedConsent: Bool = false
    
    // Reward sound player
    @State private var rewardPlayer: AVAudioPlayer? = nil
    
    // Loss sound player
    @State private var lossPlayer: AVAudioPlayer? = nil
    
    // Deposit/withdraw sound player
    @State private var goldSackPlayer: AVAudioPlayer? = nil
    
    // Background music player
    @State private var backgroundPlayer: AVAudioPlayer? = nil
    
    // Settings popup and volumes
    @State private var showingSettings: Bool = false
    @State private var musicVolume: Float = 0.02
    @State private var sfxVolume: Float = 1.0
    
    // Added state for settings segmented control
    @State private var settingsSection: SettingsSection = .audio
    @State private var sheetSection: SettingsSection = .audio
    
    // New states for slide-out settings panel and sheet
    @State private var settingsPanelWidth: CGFloat = 220
    @State private var settingsPanelOffset: CGFloat = -220
    @State private var settingsDragOffset: CGFloat = 0
    
    // UI animation & progress helpers
    @Namespace private var settingsNamespace
    @State private var selectedSettingsTabID: String = SettingsSection.audio.id
    // Daily streak target for progress (example: fill to next whole multiplier)
    private var dailyStreakProgress: Double {
        // progress within the current whole-number streak tier (e.g., 1.0..2.0)
        let fractional = currentStreak - floor(currentStreak)
        return min(max(fractional, 0), 1)
    }
    // Upgrade tier progress (0..4 based on purchased flags)
    private var upgradeTierProgress: Double {
        let tiers = [hasIncomePerMinute, hasIncomePer30s, hasIncomePer15s, hasIncomePer1s]
        let count = tiers.filter { $0 }.count
        return Double(count) / 4.0
    }
    
    // Upgrades: income tiers and overlay toggles
    @State private var hasIncomePerMinute: Bool = false
    @State private var hasIncomePer30s: Bool = false
    @State private var hasIncomePer15s: Bool = false
    @State private var hasIncomePer1s: Bool = false
    @State private var showingIncomeMinuteConfirm: Bool = false
    @State private var showingIncome30sConfirm: Bool = false
    @State private var showingIncome15sConfirm: Bool = false
    @State private var showingIncome1sConfirm: Bool = false
    
    @State private var incomeSecondCounter: Int = 0
    @State private var incomePerSecond: Double = 0
    
    // Stats tracking
    @State private var totalMoneyMade: Double = 0.0
    @State private var longestWinStreak: Int = 0
    @State private var currentWinStreak: Int = 0
    @State private var longestLossStreak: Int = 0
    @State private var currentLossStreak: Int = 0
    @State private var largestSingleGain: Double = 0.0
    @State private var gamesPlayed: Int = 0
    @State private var gamesWon: Int = 0
    @State private var highestNetworth: Double = 0.0
    
    // New state for showing user info sheet
    @State private var showingUserInfo: Bool = false
    @State private var storedUsername: String? = nil
    @State private var storedDisplayName: String? = nil
    @State private var showingAddFriend: Bool = false

    @State private var showingFriendRequests: Bool = false
    @State private var friendRequestsCount: Int = 0

    // MARK: - Persistence keys
    private enum PersistKey {
        static func currentStreak(_ uid: String) -> String { "cv.\(uid).currentStreak" }
        static func streakMultiplier(_ uid: String) -> String { "cv.\(uid).streakMultiplier" }
        static func timeRemaining(_ uid: String) -> String { "cv.\(uid).timeRemaining" }
        static func adCooldownRemaining(_ uid: String) -> String { "cv.\(uid).adCooldownRemaining" }

        static func hasIncomePerMinute(_ uid: String) -> String { "cv.\(uid).hasIncomePerMinute" }
        static func hasIncomePer30s(_ uid: String) -> String { "cv.\(uid).hasIncomePer30s" }
        static func hasIncomePer15s(_ uid: String) -> String { "cv.\(uid).hasIncomePer15s" }
        static func hasIncomePer1s(_ uid: String) -> String { "cv.\(uid).hasIncomePer1s" }

        static func isStreakProtected(_ uid: String) -> String { "cv.\(uid).isStreakProtected" }
        static func hasUsedProtectionForCurrentStreak(_ uid: String) -> String { "cv.\(uid).hasUsedProtectionForCurrentStreak" }

        static func musicVolume(_ uid: String) -> String { "cv.\(uid).musicVolume" }
        static func sfxVolume(_ uid: String) -> String { "cv.\(uid).sfxVolume" }

        static func coins(_ uid: String) -> String { "cv.\(uid).coins" }
        static func money(_ uid: String) -> String { "cv.\(uid).money" }

        static func totalMoneyMade(_ uid: String) -> String { "cv.\(uid).totalMoneyMade" }
        static func longestWinStreak(_ uid: String) -> String { "cv.\(uid).longestWinStreak" }
        static func currentWinStreak(_ uid: String) -> String { "cv.\(uid).currentWinStreak" }
        static func longestLossStreak(_ uid: String) -> String { "cv.\(uid).longestLossStreak" }
        static func currentLossStreak(_ uid: String) -> String { "cv.\(uid).currentLossStreak" }

        static func largestSingleGain(_ uid: String) -> String { "cv.\(uid).largestSingleGain" }
        static func gamesPlayed(_ uid: String) -> String { "cv.\(uid).gamesPlayed" }
        static func gamesWon(_ uid: String) -> String { "cv.\(uid).gamesWon" }
        static func highestNetworth(_ uid: String) -> String { "cv.\(uid).highestNetworth" }
    }
    
    private func updateCoinsPerSecond() {
        var rate: Double = 0

        if hasIncomePerMinute {
            rate += 1.0 / 60.0
        }
        if hasIncomePer30s {
            rate += 1.0 / 30.0
        }
        if hasIncomePer15s {
            rate += 1.0 / 15.0
        }
        if hasIncomePer1s {
            rate += 1.0
        }

        coinsPerSecond = rate
        
        print("DEBUG income flags:",
              "minute =", hasIncomePerMinute,
              "30s =", hasIncomePer30s,
              "15s =", hasIncomePer15s,
              "1s =", hasIncomePer1s,
              "=> coinsPerSecond =", coinsPerSecond)

        guard let uid = Auth.auth().currentUser?.uid else { return }

        Task {
            try? await Firestore.firestore().collection("users").document(uid).updateData([
                "coinsPerSecond": rate,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }
    
    
    
    private func loadPersistedState() {
        let d = UserDefaults.standard

        if d.object(forKey: PersistKey.currentStreak(uid)) != nil {
            currentStreak = max(1.0, d.double(forKey: PersistKey.currentStreak(uid)))
        }

        if d.object(forKey: PersistKey.streakMultiplier(uid)) != nil {
            streakMultiplier = max(1.0, d.double(forKey: PersistKey.streakMultiplier(uid)))
        } else {
            streakMultiplier = max(1.0, currentStreak)
        }

        if d.object(forKey: PersistKey.timeRemaining(uid)) != nil {
            timeRemaining = max(0, d.integer(forKey: PersistKey.timeRemaining(uid)))
        }

        if d.object(forKey: PersistKey.adCooldownRemaining(uid)) != nil {
            adCooldownRemaining = max(0, d.integer(forKey: PersistKey.adCooldownRemaining(uid)))
        }

        hasIncomePerMinute = d.bool(forKey: PersistKey.hasIncomePerMinute(uid))
        hasIncomePer30s = d.bool(forKey: PersistKey.hasIncomePer30s(uid))
        hasIncomePer15s = d.bool(forKey: PersistKey.hasIncomePer15s(uid))
        hasIncomePer1s = d.bool(forKey: PersistKey.hasIncomePer1s(uid))

        isStreakProtected = d.bool(forKey: PersistKey.isStreakProtected(uid))
        hasUsedProtectionForCurrentStreak = d.bool(forKey: PersistKey.hasUsedProtectionForCurrentStreak(uid))

        if d.object(forKey: PersistKey.musicVolume(uid)) != nil {
            musicVolume = d.float(forKey: PersistKey.musicVolume(uid))
        }

        if d.object(forKey: PersistKey.sfxVolume(uid)) != nil {
            sfxVolume = d.float(forKey: PersistKey.sfxVolume(uid))
        }

        if d.object(forKey: PersistKey.coins(uid)) != nil {
            economy.coins = d.double(forKey: PersistKey.coins(uid))
        }

        if d.object(forKey: PersistKey.money(uid)) != nil {
            economy.money = d.double(forKey: PersistKey.money(uid))
        }

        if d.object(forKey: PersistKey.totalMoneyMade(uid)) != nil {
            totalMoneyMade = d.double(forKey: PersistKey.totalMoneyMade(uid))
        }

        if d.object(forKey: PersistKey.longestWinStreak(uid)) != nil {
            longestWinStreak = d.integer(forKey: PersistKey.longestWinStreak(uid))
        }

        if d.object(forKey: PersistKey.currentWinStreak(uid)) != nil {
            currentWinStreak = d.integer(forKey: PersistKey.currentWinStreak(uid))
        }

        if d.object(forKey: PersistKey.longestLossStreak(uid)) != nil {
            longestLossStreak = d.integer(forKey: PersistKey.longestLossStreak(uid))
        }

        if d.object(forKey: PersistKey.currentLossStreak(uid)) != nil {
            currentLossStreak = d.integer(forKey: PersistKey.currentLossStreak(uid))
        }

        if d.object(forKey: PersistKey.largestSingleGain(uid)) != nil {
            largestSingleGain = d.double(forKey: PersistKey.largestSingleGain(uid))
        }

        if d.object(forKey: PersistKey.gamesPlayed(uid)) != nil {
            gamesPlayed = d.integer(forKey: PersistKey.gamesPlayed(uid))
        }

        if d.object(forKey: PersistKey.gamesWon(uid)) != nil {
            gamesWon = d.integer(forKey: PersistKey.gamesWon(uid))
        }

        if d.object(forKey: PersistKey.highestNetworth(uid)) != nil {
            highestNetworth = d.double(forKey: PersistKey.highestNetworth(uid))
        }
    }

    private func persistState() {
        let d = UserDefaults.standard

        d.set(currentStreak, forKey: PersistKey.currentStreak(uid))
        d.set(streakMultiplier, forKey: PersistKey.streakMultiplier(uid))
        d.set(timeRemaining, forKey: PersistKey.timeRemaining(uid))
        d.set(adCooldownRemaining, forKey: PersistKey.adCooldownRemaining(uid))

        d.set(hasIncomePerMinute, forKey: PersistKey.hasIncomePerMinute(uid))
        d.set(hasIncomePer30s, forKey: PersistKey.hasIncomePer30s(uid))
        d.set(hasIncomePer15s, forKey: PersistKey.hasIncomePer15s(uid))
        d.set(hasIncomePer1s, forKey: PersistKey.hasIncomePer1s(uid))

        d.set(isStreakProtected, forKey: PersistKey.isStreakProtected(uid))
        d.set(hasUsedProtectionForCurrentStreak, forKey: PersistKey.hasUsedProtectionForCurrentStreak(uid))

        d.set(musicVolume, forKey: PersistKey.musicVolume(uid))
        d.set(sfxVolume, forKey: PersistKey.sfxVolume(uid))

        d.set(economy.coins, forKey: PersistKey.coins(uid))
        d.set(economy.money, forKey: PersistKey.money(uid))

        d.set(totalMoneyMade, forKey: PersistKey.totalMoneyMade(uid))
        d.set(longestWinStreak, forKey: PersistKey.longestWinStreak(uid))
        d.set(currentWinStreak, forKey: PersistKey.currentWinStreak(uid))
        d.set(longestLossStreak, forKey: PersistKey.longestLossStreak(uid))
        d.set(currentLossStreak, forKey: PersistKey.currentLossStreak(uid))
        d.set(largestSingleGain, forKey: PersistKey.largestSingleGain(uid))
        d.set(gamesPlayed, forKey: PersistKey.gamesPlayed(uid))
        d.set(gamesWon, forKey: PersistKey.gamesWon(uid))
        d.set(highestNetworth, forKey: PersistKey.highestNetworth(uid))
    }

    // Consistent streak handling
    private func applyWin(to binding: Binding<Double>, baseChange: Double, isCoins: Bool) {
        // Apply current multiplier to winnings; first win uses current, then increment for next time
        let winnings = baseChange * streakMultiplier
        let target = binding.wrappedValue + winnings
        playRewardSound()
        
        // Update stats
        if baseChange > 0 {
            totalMoneyMade += winnings
        }
        gamesPlayed += 1
        gamesWon += 1
        
        currentWinStreak += 1
        if currentWinStreak > longestWinStreak {
            longestWinStreak = currentWinStreak
        }
        currentLossStreak = 0
        
        if winnings > largestSingleGain {
            largestSingleGain = winnings
        }
        
        // Replaced direct update with recomputeStats
        // let currentNetworth = coins + money
        // if currentNetworth > highestNetworth {
        //    highestNetworth = currentNetworth
        // }
        recomputeStats()
        
        animateValue(value: binding, to: target, isCoins: isCoins)
        
        // Increment multiplier AFTER applying this win so the next consecutive win uses +0.1 multiplier
        currentStreak += 0.1
        streakMultiplier = max(1.0, currentStreak)
        lastTotals = (economy.coins, economy.money)
    }
    
    private func applyLoss(to binding: Binding<Double>, lossAmount: Double, isCoins: Bool) {
        playLossSound()
        let target = max(0.0, binding.wrappedValue - lossAmount)
        animateValue(value: binding, to: target, isCoins: isCoins)
        
        gamesPlayed += 1
        
        currentLossStreak += 1
        if currentLossStreak > longestLossStreak {
            longestLossStreak = currentLossStreak
        }
        currentWinStreak = 0
        
        // Replaced direct update with recomputeStats
        // let currentNetworth = coins + money
        // if currentNetworth > highestNetworth {
        //     highestNetworth = currentNetworth
        // }
        recomputeStats()
        
        if isStreakProtected {
            // Consume protection: keep current multiplier, then clear protection
            isStreakProtected = false
        } else {
            currentStreak = 1.0
            streakMultiplier = 1.0
            hasUsedProtectionForCurrentStreak = false
        }
        lastTotals = (economy.coins, economy.money)
    }
    
    private func animateValue(value: Binding<Double>, to target: Double, isCoins: Bool) {
        let start = value.wrappedValue
        let delta = target - start
        guard delta != 0 else { return }
        
        isAnimatingValue = true
        
        let totalDuration: Double = 1.5
        let fps: Double = 60
        let steps = Int(totalDuration * fps)
        
        let increasing = delta > 0
        
        if isCoins {
            isAnimatingCoinsIncrease = increasing
            isAnimatingCoinsDecrease = !increasing
        } else {
            isAnimatingMoneyIncrease = increasing
            isAnimatingMoneyDecrease = !increasing
        }
        
        var frame = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { timer in
            frame += 1
            
            // Ease-out curve (sleek feel)
            let t = Double(frame) / Double(steps)
            let eased = 1 - pow(1 - t, 3)
            
            let current = start + delta * eased
            value.wrappedValue = (current * 100).rounded() / 100
            
            if frame >= steps {
                timer.invalidate()
                value.wrappedValue = (target * 100).rounded() / 100
                
                recomputeStats()
                
                isAnimatingValue = false
                
                if isCoins {
                    isAnimatingCoinsIncrease = false
                    isAnimatingCoinsDecrease = false
                } else {
                    isAnimatingMoneyIncrease = false
                    isAnimatingMoneyDecrease = false
                    isAnimatingValue = false
                }
            }
        }
    }
    
    private func playRewardSound() {
        // Attempt to reuse player if already loaded
        if let player = rewardPlayer {
            player.currentTime = 0
            player.volume = sfxVolume
            player.play()
            return
        }
        // Load the specific win sound asset
        if let url = Bundle.main.url(forResource: "WinSound1", withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = sfxVolume
                player.prepareToPlay()
                rewardPlayer = player
                player.play()
                return
            } catch {
                // Failed to load win sound; do nothing
            }
        }
        // If not found, do nothing
    }
    
    private func playLossSound() {
        if let player = lossPlayer {
            player.currentTime = 0
            player.volume = sfxVolume
            player.play()
            return
        }
        if let url = Bundle.main.url(forResource: "LoseSound1", withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = sfxVolume
                player.prepareToPlay()
                lossPlayer = player
                player.play()
                return
            } catch {
                // Failed to load loss sound; silently ignore
            }
        }
    }
    
    private func playGoldSackSound() {
        if let player = goldSackPlayer {
            player.currentTime = 0
            player.volume = sfxVolume
            player.play()
            return
        }
        if let url = Bundle.main.url(forResource: "gold_sack", withExtension: "wav") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = sfxVolume
                player.prepareToPlay()
                goldSackPlayer = player
                player.play()
                return
            } catch {
                // Failed to load gold_sack.wav; do nothing
            }
        }
    }
    
    private func startBackgroundMusic() {
        if backgroundPlayer != nil { return }
        guard let url = Bundle.main.url(forResource: "two_left_socks_correct", withExtension: "m4a") else {
            #if DEBUG
            print("[BGMusic] two_left_socks.m4a not found in bundle")
            #endif
            return
        }
        #if DEBUG
        print("[BGMusic] URL:", url)
        #endif
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // loop indefinitely
            player.volume = musicVolume // reflect user-controlled music volume
            player.prepareToPlay()
            player.play()
            backgroundPlayer = player
        } catch {
            #if DEBUG
            print("[BGMusic] failed to start:", error)
            #endif
        }
    }
    
    private func pauseBackgroundMusic() {
        backgroundPlayer?.pause()
    }
    
    private func resumeBackgroundMusic() {
        if let player = backgroundPlayer, !player.isPlaying {
            player.volume = musicVolume
            player.play()
        }
    }
    
    private func stopBackgroundMusic() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
    }
    
    private func applyVolumes() {
        // Music
        backgroundPlayer?.volume = musicVolume
        // SFX
        rewardPlayer?.volume = sfxVolume
        goldSackPlayer?.volume = sfxVolume
        lossPlayer?.volume = sfxVolume
        // Propagate to roulette views
        RouletteWheelView.sharedSFXVolume = sfxVolume
        RouletteNumberWheelView.sharedSFXVolume = sfxVolume
    }
    
    private func glow(_ binding: Binding<Bool>) {
        binding.wrappedValue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            binding.wrappedValue = false
        }
    }
    
    private func updateStreak(previous: (coins: Double, money: Double), new: (coins: Double, money: Double)) {
        let prevTotal = previous.coins + previous.money
        let newTotal = new.coins + new.money
        if newTotal > prevTotal {
            currentStreak += 0.1
        } else if newTotal < prevTotal {
            currentStreak = 1.0
        }
        streakMultiplier = max(1.0, currentStreak)
        lastTotals = new
    }
    
    private func recomputeStats() {
        let currentNetworth = economy.netWorth
        if currentNetworth > highestNetworth {
            highestNetworth = currentNetworth
        }
        coinsPerSecond = 0

        if hasIncomePerMinute { coinsPerSecond += 1.0 / 60.0 }
        if hasIncomePer30s { coinsPerSecond += 1.0 / 30.0 }
        if hasIncomePer15s { coinsPerSecond += 1.0 / 15.0 }
        if hasIncomePer1s { coinsPerSecond += 1.0 }
    }
    
    private func updateUserEconomyToFirestore() async {
        let uid = auth.user?.uid ?? Auth.auth().currentUser?.uid
        guard let uid else { return }
        let doc = Firestore.firestore().collection("users").document(uid)
        let data: [String: Any] = [
            "coins": economy.coins,
            "money": economy.money,
            "netWorth": economy.coins + economy.money,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do { try await doc.setData(data, merge: true) } catch { }
    }
    
    // Popup mode for choosing between adding to coins or withdrawing from coins to cash
    enum PopupMode { case add, withdraw }
    
    // Enum for segmented settings sections
    enum SettingsSection: String, CaseIterable, Identifiable {
        case audio = "Audio"
        case stats = "Stats"
        case upgrades = "Upgrades"
        case premium = "Premium"
        case privacy = "Privacy"
        case friends = "Friends"
        var id: String { rawValue }
    }
    
    // Helper to map icons for sections
    private func iconFor(_ section: SettingsSection) -> String {
        switch section {
        case .audio: return "speaker.wave.3.fill"
        case .stats: return "chart.bar.xaxis"
        case .upgrades: return "star.fill"
        case .premium: return "crown.fill"
        case .privacy: return "hand.raised.fill"
        case .friends: return "person.3.fill"
        }
    }
    
    // Reusable upgrade row card
    @ViewBuilder
    private func upgradeRow(icon: String, title: String, purchased: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.primary)
                    Text(purchased ? "Purchased" : "Tap to purchase")
                        .font(.caption2)
                        .foregroundColor(purchased ? .green : .secondary)
                }
                Spacer()
                if purchased {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    
    var backgroundView: some View {
        // Replaced background image with linear gradient and blur for modern finance feel
        LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .blur(radius: 6)
    }
    
    var mainButtonsGrid: some View {
        VStack(spacing: 0) {
            VStack(spacing: 50) {
                topAdButtonRow
                twoColumnGameButtons
            }
            .padding(.top, 200)
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .center)
        .padding(.top, 0)
        .padding(.bottom, -200)
    }
    
    var bottomBanner: some View {
        BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2435281174")
            .frame(width: 320, height: 50)
            .padding(.bottom, 12)
    }
    
    var topAdButtonRow: some View {
        HStack {
            Spacer()
            if adCooldownRemaining > 0 {
                ZStack {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.2))
                        .shadow(radius: 1)
                    Text(formatMinuteSecond(adCooldownRemaining))
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                        .shadow(radius: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: 40)
                .padding(.horizontal, 12)
                .cornerRadius(120)
            } else {
                Button(action: watchAdForCoins) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                        Text("Watch an ad to earn $100")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.green]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                    .shadow(radius: 6)
                }
                .disabled(adCooldownRemaining > 0) // removed dependency on isRewardAdReady
                .buttonStyle(PressScaleButtonStyle())
                .padding(.horizontal, 12)
            }
            Spacer()
        }
        .padding(.top, 20)
    }
    
    var twoColumnGameButtons: some View {
        HStack(spacing: 8) {
            VStack(spacing: 16) {
                // Replaced all gambling buttons with finance-themed SF Symbol labeled buttons
                
                VStack {
                    Button {
                        doubleOrNothingTapped()
                        AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "plusminus.circle.fill")
                                .font(.title)
                            Text("Double or Nothing")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Button {
                        showingHighRiskConfirm = true; AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.title)
                            Text("High Risk / Reward")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Button {
                        showingLotteryConfirm = true; AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "shield.lefthalf.fill")
                                .font(.title)
                            Text("Low Roller Lottery")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .alert("Not enough funds!", isPresented: $showAlert) { Button("OK", role: .cancel) {} }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Button {
                        showingHighRollerConfirm = true; AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "banknote.fill")
                                .font(.title)
                            Text("High Roller Lottery")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .alert("Not enough funds!", isPresented: $showAlert) { Button("OK", role: .cancel) {} }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 16) {
                VStack {
                    Button {
                        showingSuperHighRollerConfirm = true; AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "medal.star")
                                .font(.title)
                                Text("Premium Lottery")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .alert("Not enough funds!", isPresented: $showAlert) { Button("OK", role: .cancel) {} }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Button {
                        showingDollarForTwoConfirm = true; AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.title)
                            Text("$1 for $2")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .alert("Not enough funds!", isPresented: $showAlert) { Button("OK", role: .cancel) {} }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Button {
                        activeSheet = .roulette; AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "multiply.circle.fill")
                                .font(.title)
                            Text("Multiplier Spin")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Button {
                        activeSheet = .roulette2; AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    } label: {
                        HStack {
                            Image(systemName: "number.circle.fill")
                                .font(.title)
                            Text("Number Spin")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    var topLeftAccountPanel: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.bank.building.fill")
                        .foregroundColor(.green)
                    Text("Bank:")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("$\(formatNumber(economy.coins))")
                        .monospacedDigit()
                        .frame(minWidth: 0, alignment: .leading)
                        .fontWeight(.bold)
                        .font(.subheadline)
                        .foregroundColor(isAnimatingCoinsIncrease ? .green : (isAnimatingCoinsDecrease ? .gray : .primary))
                }
                HStack(spacing: 0) {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.blue)
                    Text("Current Bet:")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("$\(formatNumber(economy.money))")
                        .monospacedDigit()
                        .frame(minWidth: 10, alignment: .leading)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isAnimatingMoneyIncrease ? .green : (isAnimatingMoneyDecrease ? .gray : .primary))
                }
                HStack(spacing: 12) {
                    Button(action: { popupMode = .withdraw; amountText = ""; showingAmountPopup = true }) {
                        Image(systemName: "arrow.up.right.circle")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    
                    Button(action: { popupMode = .add; amountText = ""; showingAmountPopup = true }) {
                        Image(systemName: "arrow.down.left.circle")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
                
            }
            .frame(minWidth: 200)
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(radius: 5)
            .padding(.leading, 12)
            .padding(.top, 10)
            Spacer()
            rightStatusPanel
        }
        .zIndex(1000)
        .allowsHitTesting(true)
    }
    
    var rightStatusPanel: some View {
        VStack(alignment: .trailing, spacing: 8) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("$100 will be added in:")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text(formatTime(timeRemaining))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.green)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 6)
            
            HStack(spacing: 6) {
                Text("Current multiplier: \(String(format: "%.1f", streakMultiplier))")
                    .font(.caption)
                    .foregroundColor(isStreakProtected ? .green : .primary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 6)
            if streakMultiplier > 1.4 && !hasUsedProtectionForCurrentStreak {
                Button(action: { showingProtectionConfirm = true }) {
                    Text("Watch ad to protect!")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            HStack(spacing: 6) {
                Button(action: { if auth.user == nil { activeSheet = nil } else { showingUserInfo = true } }) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 4)
        }
        .padding(.trailing, 12)
        .padding(.top, 20)
    }
    
    // New settings chevron handle view
    var settingsChevronHandle: some View {
        let totalOffset = settingsPanelOffset + settingsDragOffset
        // Compute the chevron's X so it stays attached to the right edge of the sliding panel.
        // When hidden: settingsPanelOffset == -settingsPanelWidth, so handleX == 0 (at screen edge).
        // When open: settingsPanelOffset == 0, so handleX == settingsPanelWidth (attached to panel's right edge).
        let handleX = max(-settingsPanelWidth, totalOffset) + settingsPanelWidth

        return VStack {
            Spacer().frame(height: 140) // position below account panel
            Button(action: {
                let shouldOpen = settingsPanelOffset <= -settingsPanelWidth * 0.5
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    settingsPanelOffset = shouldOpen ? 0 : -settingsPanelWidth
                    settingsDragOffset = 0
                }
            }) {
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 24, height: 80)
                        .shadow(radius: 2)
                    Image(systemName: totalOffset < -settingsPanelWidth/2 ? "chevron.right" : "chevron.left")
                        .foregroundColor(.blue)
                        .font(.headline)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(width: 30)
        // Attach the chevron to the panel's right edge by offsetting horizontally
        .offset(x: handleX)
    }
    
    // New slide-out settings list panel
    var settingsSlideOutPanel: some View {
        let xOffset = settingsPanelOffset + settingsDragOffset
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                SectionRow(icon: "speaker.wave.3.fill", title: "Audio", isSelected: false) {
                    sheetSection = .audio; selectedSettingsTabID = SettingsSection.audio.id; activeSheet = .settings
                }
                SectionRow(icon: "chart.bar.xaxis", title: "Stats", isSelected: false) {
                    sheetSection = .stats; selectedSettingsTabID = SettingsSection.stats.id; activeSheet = .settings
                }
                SectionRow(icon: "star.fill", title: "Upgrades", isSelected: false) {
                    sheetSection = .upgrades; selectedSettingsTabID = SettingsSection.upgrades.id; activeSheet = .settings
                }
                SectionRow(icon: "crown.fill", title: "Premium", isSelected: false) {
                    sheetSection = .premium; selectedSettingsTabID = SettingsSection.premium.id; activeSheet = .settings
                }
                SectionRow(icon: "hand.raised.fill", title: "Privacy", isSelected: false) {
                    sheetSection = .privacy; selectedSettingsTabID = SettingsSection.privacy.id; activeSheet = .settings
                }
                SectionRow(icon: "person.3.fill", title: "Friends", isSelected: false) {
                    sheetSection = .friends; selectedSettingsTabID = SettingsSection.friends.id; activeSheet = .settings
                }
                Button("Log out") {
                    activeSheet = nil
                    do { try auth.signOut() }
                    catch { print("Sign out error:", error) }
                }
                .buttonStyle(.bordered)
                .padding(.top, 24)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: settingsPanelWidth)
            .background(.ultraThinMaterial)
            .shadow(radius: 6)
            Spacer(minLength: 0)
        }
        .offset(x: xOffset)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: settingsDragOffset)
    }
    
    // Sheet content builder for settingsSheetContent
    @ViewBuilder
    var settingsSheetContent: some View {
        switch sheetSection {
        case .audio:
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.3.fill").foregroundColor(.blue)
                        Text("Audio").font(.title3).bold().foregroundColor(.primary)
                    }
                    Text("Tune the experience to your liking.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note").foregroundColor(.blue)
                            Text("Music Volume").font(.subheadline).foregroundColor(.primary)
                        }
                        Slider(
                            value: Binding(get: { Double(musicVolume) }, set: { newVal in musicVolume = Float(newVal); applyVolumes() }),
                            in: 0...1
                        )
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform").foregroundColor(.green)
                            Text("Sound Effects").font(.subheadline).foregroundColor(.primary)
                        }
                        Slider(
                            value: Binding(get: { Double(sfxVolume) }, set: { newVal in sfxVolume = Float(newVal); applyVolumes() }),
                            in: 0...1
                        )
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        case .stats:
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.bar.xaxis").foregroundColor(.green)
                        Text("Your Performance").font(.title3).bold()
                    }
                    Text("Track your progress and aim for new highs.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        let winRateString = gamesPlayed > 0 ? String(format: "%.1f", Double(gamesWon) * 100.0 / Double(gamesPlayed)) : "0"
                        HStack { Image(systemName: "crown").foregroundColor(.yellow); Text("Highest net worth: $\(formatNumber(highestNetworth))").font(.subheadline) }
                        HStack { Image(systemName: "dollarsign.circle").foregroundColor(.blue); Text("Total money made: $\(formatNumber(totalMoneyMade))").font(.subheadline) }
                        HStack { Image(systemName: "flame").foregroundColor(.red); Text("Longest win streak: \(longestWinStreak)").font(.subheadline) }
                        HStack { Image(systemName: "snow").foregroundColor(.cyan); Text("Longest loss streak: \(longestLossStreak)").font(.subheadline) }
                        HStack { Image(systemName: "arrow.up.right").foregroundColor(.green); Text("Largest single gain: $\(formatNumber(largestSingleGain))").font(.subheadline) }
                        HStack { Image(systemName: "percent").foregroundColor(.orange); Text("Win Rate: \(winRateString)%").font(.subheadline) }
                        HStack { Image(systemName: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90").foregroundColor(.orange); Text("Passive income: $\(String(format: "%.2f", coinsPerSecond))/sec").font(.subheadline) }
                        
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        case .upgrades:
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill").foregroundColor(.blue)
                            Text("Income Upgrades").font(.title3).bold()
                        }
                        Text("Stack upgrades to grow your passive income while you play.")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Upgrade tier progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: upgradeTierProgress)
                                .tint(.blue)
                            Text("\(Int(upgradeTierProgress * 100))% of tiers unlocked")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)

                        Divider().padding(.vertical, 4)

                        VStack(spacing: 10) {
                            upgradeRow(icon: "clock", title: "Pay $40,000 to earn $1 every minute?", purchased: hasIncomePerMinute) {
                                showingIncomeMinuteConfirm = true
                            }
                            upgradeRow(icon: "clock", title: "Pay $70,000 to earn $1 every 30 seconds?", purchased: hasIncomePer30s) {
                                showingIncome30sConfirm = true
                            }
                            upgradeRow(icon: "clock", title: "Pay $120,000 to earn $1 every 15 seconds?", purchased: hasIncomePer15s) {
                                showingIncome15sConfirm = true
                            }
                            upgradeRow(icon: "clock", title: "Pay $1,000,000 to earn $1 every second?", purchased: hasIncomePer1s) {
                                showingIncome1sConfirm = true
                            }
                        }
                    }
                    .padding()
                }

                if showingIncomeMinuteConfirm { incomeMinuteOverlay }
                if showingIncome30sConfirm { income30sOverlay }
                if showingIncome15sConfirm { income15sOverlay }
                if showingIncome1sConfirm { income1sOverlay }
            }
        case .premium:
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill").foregroundColor(.yellow)
                        Text("Premium Pass").font(.title3).bold()
                    }
                    Text("Unlock exclusive tools and remove ads for a smoother experience!")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "nosign.app.fill").foregroundColor(.green); Text("Remove popup ads") }
                        HStack { Image(systemName: "clock.arrow.circlepath").foregroundColor(.green); Text("Fixed income of $1 every 15 seconds") }
                        HStack { Image(systemName: "multiply.circle.fill").foregroundColor(.green); Text("Permanent base multiplier of 1.2x") }
                        HStack { Image(systemName: "chart.bar.xaxis.ascending").foregroundColor(.green); Text("Add friends and view leaderboard") }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    Button("Subscribe for $1.49/ month") {}
                        .buttonStyle(.bordered)
                        .tint(.blue)
                }
                .padding()
            }
        case .privacy:
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised.fill").foregroundColor(.blue)
                        Text("Privacy").font(.title3).bold()
                    }
                    Text("Manage your data and read our policy.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button("Privacy Settings") {
                            Task { await ConsentManager.shared.showPrivacyOptions() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        Button("Privacy Policy") {
                            UIApplication.shared.open(AppLinks.privacyPolicy)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        case .friends:
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ZStack {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.3.fill").foregroundColor(.green)
                            Text("Friends").font(.title3).bold()
                        }
                        Text("Compete with friends and climb the leaderboard!")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("Leaderboard")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider().padding(.vertical, 4)
                        // Leaderboard embedded below the panel
                        LeaderboardView()
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showingFriendRequests = true }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "tray.badge.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                if friendRequestsCount > 0 {
                                    Text("\(friendRequestsCount)")
                                        .font(.caption2).bold()
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Circle().fill(Color.red))
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingAddFriend = true }) {
                            Image(systemName: "person.fill.badge.plus")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendsView()
            }
            .sheet(isPresented: $showingFriendRequests) {
                FriendRequestsView()
            }
            
        }
    }
    
    // --- REPLACED THE ENTIRE INNER VSTACK OF settingsOverlay STARTS HERE ---

    var offlineIncomeOverlay: some View {
        overlayContainer {
            VStack(spacing: 16) {
                Text("Welcome back!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You earned $\(formatNumber(offlineIncomeAmount)) while away 💰")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Button("Collect") {
                    showingOfflineIncomePopup = false
                }
                .buttonStyle(.borderedProminent)
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }
    
    var protectionOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Watch an ad to protect your multiplier from resetting on your next loss?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Close") { showingProtectionConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button("Watch ad") {
                        showingProtectionConfirm = false
                        if !isStreakProtected {
                            pauseBackgroundMusic()
                            rewardedAdManager.showAd {
                                isStreakProtected = true
                                hasUsedProtectionForCurrentStreak = true
                                resumeBackgroundMusic()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    var highRiskOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("90% chance to reduce your bet by 90%, 10% chance to multiply your bet by 10!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Not right now.") { showingHighRiskConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button("Let's do it!") {
                        let oneInTen = Int.random(in: 1...10)
                        if oneInTen == 1 {
                            let baseGain = economy.money * 9.0
                            applyWin(to: moneyBinding, baseChange: baseGain, isCoins: false)
                            glow($glowTenX)
                        } else {
                            applyLoss(to: moneyBinding, lossAmount: economy.money * 0.9, isCoins: false)
                        }
                        showingHighRiskConfirm = false
                        AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    var lotteryOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Spend $100 for a 2% chance to win $5000?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Not right now.") { showingLotteryConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button("Let's do it!") {
                        if economy.coins >= 100.0 {
                            let twopercent = Int.random(in: 1...50)
                            if twopercent == 1 {
                                applyWin(to: coinsBinding, baseChange: 5000.0, isCoins: true)
                                glow($glowTwoPercent)
                            } else {
                                applyLoss(to: coinsBinding, lossAmount: 100.0, isCoins: true)
                            }
                        } else {
                            showAlert = true
                        }
                        showingLotteryConfirm = false
                        AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    var highRollerOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Spend $250 for a 10% chance of winning $2,500?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Not right now") { showingHighRollerConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button("Let's do it!") {
                        if economy.coins >= 250.0 {
                            let tenpercent = Int.random(in: 1...10)
                            if tenpercent == 1 {
                                applyWin(to: coinsBinding, baseChange: 2500.0, isCoins: true)
                                glow($glowTenPercent)
                            } else {
                                applyLoss(to: coinsBinding, lossAmount: 250.0, isCoins: true)
                            }
                        } else {
                            showAlert = true
                        }
                        showingHighRollerConfirm = false
                        AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    var superHighRollerOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Spend $100 for a 1% chance of winning $10,000?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Not right now") { showingSuperHighRollerConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button("Let's do it!") {
                        if economy.coins >= 100.0 {
                            let onepercent = Int.random(in: 1...100)
                            if onepercent == 1 {
                                applyWin(to: coinsBinding, baseChange: 10000.0, isCoins: true)
                                glow($glowOnePercent)
                            } else {
                                applyLoss(to: coinsBinding, lossAmount: 100.0, isCoins: true)
                            }
                        } else {
                            showAlert = true
                        }
                        showingSuperHighRollerConfirm = false
                        AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    var dollarForTwoOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Spend $1 for a 50% chance of winning $2?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Not right now.") { showingDollarForTwoConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button("Let's do it!") {
                        if economy.coins >= 1.0 {
                            let fiftypercent = Int.random(in: 1...2)
                            if fiftypercent == 1 {
                                applyWin(to: coinsBinding, baseChange: 1.0, isCoins: true)
                                glow($glowFiftyPercent)
                            } else {
                                applyLoss(to: coinsBinding, lossAmount: 1.0, isCoins: true)
                            }
                        } else {
                            showAlert = true
                        }
                        showingDollarForTwoConfirm = false
                        AdFrequencyController.shared.registerActionAndMaybeShowAd()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    var incomeMinuteOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Pay $40,000 to earn $1 every minute?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Close") { showingIncomeMinuteConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button(hasIncomePerMinute ? "Purchased" : "Pay $40,000") {
                        if !hasIncomePerMinute {
                            if economy.coins >= 40000.0 {
                                Task { await economy.addCoins(-40000.0) }
                                hasIncomePerMinute = true
                                updateCoinsPerSecond()
                                Task { await upgrades.incrementLevel(for: "u_minute") }
                            } else { showAlert = true }
                        }
                        showingIncomeMinuteConfirm = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(hasIncomePerMinute)
                }
            }
        }
    }

    var income30sOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Pay $70,000 to earn $1 every 30 seconds?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Close") { showingIncome30sConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button(hasIncomePer30s ? "Purchased" : "Pay $70,000") {
                        if !hasIncomePer30s {
                            if economy.coins >= 70000.0 {
                                Task { await economy.addCoins(-70000.0) }
                                hasIncomePer30s = true
                                updateCoinsPerSecond()
                                Task { await upgrades.incrementLevel(for: "u_30s") }
                            } else { showAlert = true }
                        }
                        showingIncome30sConfirm = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(hasIncomePer30s)
                }
            }
        }
    }

    var income15sOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Pay $120,000 to earn $1 every 15 seconds?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Close") { showingIncome15sConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button(hasIncomePer15s ? "Purchased" : "Pay $120,000") {
                        if !hasIncomePer15s {
                            if economy.coins >= 120000.0 {
                                Task { await economy.addCoins(-120000.0) }
                                hasIncomePer15s = true
                                updateCoinsPerSecond()
                                Task { await upgrades.incrementLevel(for: "u_15s") }
                            } else { showAlert = true }
                        }
                        showingIncome15sConfirm = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(hasIncomePer15s)
                }
            }
        }
    }

    var income1sOverlay: some View {
        overlayContainer {
            VStack(spacing: 12) {
                Text("Pay $1,000,000 to earn $1 every second?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                HStack(spacing: 12) {
                    Button("Close") { showingIncome1sConfirm = false }
                        .buttonStyle(.bordered)
                        .buttonStyle(PressScaleButtonStyle())
                    Button(hasIncomePer1s ? "Purchased" : "Pay $1,000,000") {
                        if !hasIncomePer1s {
                            if economy.coins >= 1000000.0 {
                                Task { await economy.addCoins(-1000000.0) }
                                hasIncomePer1s = true
                                updateCoinsPerSecond()
                                Task { await upgrades.incrementLevel(for: "u_1s") }
                            } else { showAlert = true }
                        }
                        showingIncome1sConfirm = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(hasIncomePer1s)
                }
            }
        }
    }
    // --- REPLACED THE ENTIRE INNER VSTACK OF settingsOverlay ENDS HERE ---
    
    var amountPopup: some View {
        ZStack {
            GeometryReader { _ in
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                VStack(spacing: 16) {
                    Text(popupMode == .add ? "Deposit amount:" : "Withdrawal amount:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("Enter amount", text: $amountText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    HStack {
                        Button("Close") { showingAmountPopup = false }
                            .buttonStyle(.bordered)
                            .buttonStyle(PressScaleButtonStyle())
                        Button("Confirm") { confirmAmount() }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .buttonStyle(PressScaleButtonStyle())
                            .disabled(Double(amountText) == nil || (Double(amountText) ?? 0.0) <= 0.0)
                    }
                }
                .padding()
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea(.keyboard)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    // Removed individual roulette and settings sheet states and replaced with activeSheet router
    
    private var rouletteSheet: some View {
        RouletteWheelView(isPresented: Binding(get: { activeSheet == .roulette }, set: { newValue in if !newValue { activeSheet = nil } })) { multiplier in
            let originalMoney = economy.money
            let baseComputed = originalMoney * multiplier
            if multiplier > 1.0 {
                let netGain = baseComputed - originalMoney
                applyWin(to: moneyBinding, baseChange: netGain, isCoins: false)
                glow($glowMultiplierRoulette)
                recomputeStats()
            } else if multiplier < 1.0 {
                let loss = originalMoney - baseComputed
                applyLoss(to: moneyBinding, lossAmount: loss, isCoins: false)
                recomputeStats()
            } else {
                if isStreakProtected { isStreakProtected = false } else {
                    currentStreak = 1.0; streakMultiplier = 1.0; hasUsedProtectionForCurrentStreak = false
                }
                animateValue(value: moneyBinding, to: originalMoney, isCoins: false)
                recomputeStats()
            }
            lastTotals = (economy.coins, economy.money)
        }
    }
    
    private var roulette2Sheet: some View {
        RouletteNumberWheelView(isPresented: Binding(get: { activeSheet == .roulette2 }, set: { newValue in if !newValue { activeSheet = nil } })) { pickedNumber, winningNumber, originalStake in
            if pickedNumber == winningNumber {
                let targetFinal = originalStake * 20.0 * streakMultiplier
                playRewardSound()
                animateValue(value: moneyBinding, to: targetFinal, isCoins: false)
                currentStreak += 0.1
                streakMultiplier = max(1.0, currentStreak)
                recomputeStats()
                lastTotals = (economy.coins, economy.money)
                glow($glowNumbersRoulette)
            } else {
                playLossSound()
                animateValue(value: moneyBinding, to: 0.0, isCoins: false)
                recomputeStats()
                if isStreakProtected { isStreakProtected = false } else {
                    currentStreak = 1.0; streakMultiplier = 1.0; hasUsedProtectionForCurrentStreak = false
                }
                lastTotals = (economy.coins, economy.money)
            }
        } onCommitPick: { original in
            roulette2OriginalMoney = original
        }
    }
    
    // MARK: - Small action helpers
    private func watchAdForCoins() {
        guard adCooldownRemaining == 0 else { return }
        guard isRewardAdReady else {
            // trigger a load and inform user
            NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Load"), object: nil)
            #if DEBUG
            print("[Ads] Rewarded ad not ready yet; loading...")
            #endif
            return
        }
        pauseBackgroundMusic()
        rewardedAdManager.showAd {
            Task { await economy.addCoins(100.0) }
            recomputeStats()
            adCooldownRemaining = 600
            isRewardAdReady = false
            NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Load"), object: nil)
            resumeBackgroundMusic()
        }
    }
    
    private func doubleOrNothingTapped() {
        guard economy.money > 0 else {
            showAlert = true
            return
        }
        if Bool.random() {
            let baseGain = economy.money
            applyWin(to: moneyBinding, baseChange: baseGain, isCoins: false)
            glow($glowDoubleOrNothing)
            recomputeStats()
        } else {
            playLossSound()
            applyLoss(to: moneyBinding, lossAmount: economy.money, isCoins: false)
            recomputeStats()
        }
        AdFrequencyController.shared.registerActionAndMaybeShowAd()
    }
    
    private func confirmAmount() {
        let amount = Double(amountText) ?? 0.0
        guard amount > 0.0 else { showingAmountPopup = false; return }
        switch popupMode {
        case .add:
            if amount > economy.money { showAlert = true; return }
            // Animate value changes instead of instantly setting via async
            let newCoins = economy.coins + amount
            let newMoney = max(0.0, economy.money - amount)
            animateValue(value: coinsBinding, to: newCoins, isCoins: true)
            animateValue(value: moneyBinding, to: newMoney, isCoins: false)
            playGoldSackSound()
            recomputeStats()
            showingAmountPopup = false
        case .withdraw:
            if amount > economy.coins { showAlert = true; return }
            // Animate value changes instead of instantly setting via async
            let newCoins = max(0.0, economy.coins - amount)
            let newMoney = economy.money + amount
            animateValue(value: coinsBinding, to: newCoins, isCoins: true)
            animateValue(value: moneyBinding, to: newMoney, isCoins: false)
            playGoldSackSound()
            recomputeStats()
            showingAmountPopup = false
        }
    }
    
    // Note: UMP/Google SDK may log SKAdNetwork/consent hints. Configure Info.plist with SKAdNetworkItems and UMP test IDs to silence in development.
    private func onAppearSetup() {
        lastActiveDate = Date()
        lastTotals = (economy.coins, economy.money)
        updateCoinsPerSecond()

        if currentStreak < 1.0 { currentStreak = 1.0 }
        streakMultiplier = max(1.0, currentStreak)

        NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Load"), object: nil)

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }

        startBackgroundMusic()
        applyVolumes()
        loadPersistedState()
        streakMultiplier = max(1.0, currentStreak)

        if !hasAttemptedConsent {
            runConsentAndMaybeLoadAds()
        }

        Task { await loadStoredUsername() }
        
        Task {
            let earned = await economy.claimOfflineIncomeIfNeeded()

            if earned > 0 {
                offlineIncomeAmount = earned
                showingOfflineIncomePopup = true
            }
        }
        
    }
    
    // New function to load stored username and displayName from Firestore
    private func loadStoredUsername() async {
        let uid = auth.user?.uid ?? Auth.auth().currentUser?.uid
        guard let uid else { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let data = doc.data() {
                let uname = data["username"] as? String
                let dname = data["displayName"] as? String
                await MainActor.run {
                    self.storedUsername = uname
                    self.storedDisplayName = dname
                }
            }
        } catch {
            // silently ignore
        }
    }
    
    // Note: UMP/Google SDK may log SKAdNetwork/consent hints. Configure Info.plist with SKAdNetworkItems and UMP test IDs to silence in development.
    private func runConsentAndMaybeLoadAds() {
        #if DEBUG
        print("[Consent] Starting consent flow...")
        #endif
        Task {
            await ConsentManager.shared.runConsentStartupFlow()
            let allowed = ConsentInformation.shared.canRequestAds
            DispatchQueue.main.async {
                #if DEBUG
                print("[Consent] canRequestAds=\(allowed)")
                #endif
                self.canRequestAds = allowed
                self.hasAttemptedConsent = true
                if allowed {
                    NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Load"), object: nil)
                }
            }
        }
    }
    
    private func onTick(_ : Date) {
        
        if adCooldownRemaining > 0 {
            adCooldownRemaining = max(0, adCooldownRemaining - 1)
        }

        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            economy.coins += 100.0
            pendingPassiveIncome += 100.0
            timeRemaining = 3 * 60 * 60
        }

        incomeSecondCounter += 1

        if coinsPerSecond > 0 {
            economy.coins += coinsPerSecond
            pendingPassiveIncome += coinsPerSecond
            recomputeStats()
        }

        if incomeSecondCounter >= 60 * 60 * 24 {
            incomeSecondCounter = 0
            recomputeStats()
        }

        if pendingPassiveIncome >= 10.0 || (incomeSecondCounter % 30 == 0 && pendingPassiveIncome > 0) {
            let amountToFlush = pendingPassiveIncome
            pendingPassiveIncome = 0

            if amountToFlush > 0 {
                Task { @MainActor in
                    await economy.save()

                    if let uid = Auth.auth().currentUser?.uid {
                        try? await Firestore.firestore().collection("users").document(uid).updateData([
                            "lastIncomeClaimAt": FieldValue.serverTimestamp(),
                            "updatedAt": FieldValue.serverTimestamp()
                        ])
                    }
                }
            }
        }
    }
    
    
    private func overlayContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { }
            content()
                .padding()
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
        }
        .transition(.opacity)
        .zIndex(9999)
    }
    
    
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
    
    private func formatShortTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func formatMinuteSecond(_ seconds: Int) -> String {
        return formatShortTime(seconds)
    }
    
    
    struct RouletteWheelView: View {
        @Binding var isPresented: Bool
        var onResult: (Double) -> Void
        @State private var rotation: Double = 0
        @State private var isSpinning: Bool = false
        
        // Replace SystemSoundID usage with only AVAudioPlayer pool
        @State private var clickPlayer: AVAudioPlayer? = nil
        @State private var playerPool: [AVAudioPlayer] = []
        @State private var poolIndex: Int = 0
        
        // Use a shared static to receive SFX volume from ContentView
        static var sharedSFXVolume: Float = 1.0
        
        // Timer-based animation properties
        //@State private var displayLinkTimer: Timer? = nil
        @State private var displayLink: CADisplayLink? = nil
        @State private var displayLinkProxy: DisplayLinkProxy? = nil
        @State private var spinStartTime: TimeInterval = 0
        @State private var spinDuration: TimeInterval = 3.0
        @State private var startRotation: Double = 0
        @State private var targetRotation: Double = 0
        @State private var prevPointerAngle: Double = 0
        @State private var nextSliceBoundary: Double = 0
        
        @State private var renderedWheelImage: Image? = nil
        @State private var hasRenderedWheel = false
        
        private func loadClickSound() {
            initPlayerPool()
        }
        private func playClick() {
            playLightClick()
        }
        
        private func initPlayerPool() {
            guard playerPool.isEmpty else { return }
            let urls: [URL?] = [
                Bundle.main.url(forResource: "chips-collide-1", withExtension: "wav"),
                Bundle.main.url(forResource: "click", withExtension: "wav")
            ]
            guard let url = urls.compactMap({ $0 }).first else { return }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<3 {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.volume = RouletteWheelView.sharedSFXVolume
                    p.prepareToPlay()
                    pool.append(p)
                }
            }
            playerPool = pool
            poolIndex = 0
            if clickPlayer == nil { clickPlayer = pool.first }
        }
        private func playFromPool() {
            guard !playerPool.isEmpty else { return }
            poolIndex = (poolIndex + 1) % playerPool.count
            let p = playerPool[poolIndex]
            p.volume = RouletteWheelView.sharedSFXVolume
            p.currentTime = 0
            p.play()
            clickPlayer = p
        }
        private func playLightClick() {
            AudioServicesPlaySystemSound(1104)
        }
        
        // Haptic feedback (light) with simple rate limiting
        // Removed per instructions
        
        
        private let multipliers: [Double] = Array(stride(from: 0.1, through: 2.0, by: 0.1)).map { Double(round($0 * 10) / 10) }
        
        class DisplayLinkProxy {
            var tick: (() -> Void)?
            @objc func onTick() {
                tick?()
            }
        }
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Multiplier Spin")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.blue)
                
                
                ZStack {
                    // Wrap the wheel with fixed size and drawingGroup, apply rotation to this container
                    ZStack {
                        if let rendered = renderedWheelImage {
                            rendered
                                .resizable()
                                .frame(width: 260, height: 260)
                                .rotationEffect(.degrees(rotation))
                        } else {
                            WheelShape(slices: multipliers.count)
                                .fill(.clear)
                                .overlay(
                                    FixedWheelSlices(multipliers: multipliers)
                                )
                                .frame(width: 260, height: 260)
                        }
                    }
                    .drawingGroup()
                    .zIndex(0)
                    
                    TrianglePointer()
                        .fill(Color.green.opacity(1.0))
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(180))// adjust size
                        .offset(y: -130)               // move it above the wheel
                        .shadow(radius: 1)
                    
                    
                }
                
                Button(isSpinning ? "Spinning..." : "Spin") {
                    guard !isSpinning else { return }
                    spinWheel()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .buttonStyle(PressScaleButtonStyle())
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding()
            .presentationDetents([.medium])
            
            .onAppear {
                #if DEBUG
                print("[Wheel] onAppear")
                #endif
                loadClickSound()
                if !hasRenderedWheel {
                    renderWheelImage()
                }
                do {
                    try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    #if DEBUG
                    print("[Wheel] AVAudioSession error: \(error)")
                    #endif
                }
                let session = AVAudioSession.sharedInstance()
                #if DEBUG
                print("[Wheel] Category=\(session.category.rawValue), Mode=\(session.mode.rawValue), Output=\(session.currentRoute.outputs.map{ $0.portType.rawValue }.joined(separator: ", "))")
                #endif
                // Removed NotificationCenter observer for "TestClick" per instructions
            }
            .onDisappear {
                displayLink?.invalidate()
                displayLink = nil
                displayLinkProxy = nil
            }
        }
        
        
        
        private func spinWheel() {
            isSpinning = true
            
            let degreesPerSlice = 360.0 / Double(multipliers.count)
            let fullSpins = Double.random(in: 5.0...7.0)
            let randomOffset = Double.random(in: 0..<360)
            let delta = fullSpins * 360.0 + randomOffset
            
            startRotation = rotation
            targetRotation = rotation + delta
            spinDuration = 3.0
            spinStartTime = CACurrentMediaTime()
            
            // Initialize pointer angle for click detection
            let normalizeAngle: (Double) -> Double = { angle in
                let mod = angle.truncatingRemainder(dividingBy: 360)
                return mod < 0 ? mod + 360 : mod
            }
            func pointerAngle(for rotation: Double) -> Double {
                // Top pointer is fixed at -90°, angle under pointer is (-90 - rotation)
                return normalizeAngle(-90.0 - rotation)
            }
            prevPointerAngle = pointerAngle(for: startRotation)
            // Calculate next slice boundary angle relative to progress 0.0
            // We'll track progress in degrees from startRotation, so the next boundary is the smallest multiple of degreesPerSlice larger than 0
            nextSliceBoundary = degreesPerSlice * ceil(0 / degreesPerSlice) + degreesPerSlice
            
            displayLink?.invalidate()
            let proxy = DisplayLinkProxy()
            proxy.tick = {
                let now = CACurrentMediaTime()
                let t = min(1, (now - self.spinStartTime) / self.spinDuration)
                // Ease out cubic
                let eased = 1 - pow(1 - t, 3)
                self.rotation = self.startRotation + (self.targetRotation - self.startRotation) * eased
                
                // Calculate how much progress in degrees we've made since startRotation
                let currentProgress = self.rotation - self.startRotation
                
                var clicksFired = 0
                while currentProgress >= self.nextSliceBoundary && clicksFired < 5 {
                    self.playClick()
                    self.nextSliceBoundary += degreesPerSlice
                    clicksFired += 1
                }
                
                if t >= 1.0 {
                    self.isSpinning = false
                    self.displayLink?.invalidate()
                    self.displayLink = nil
                    
                    // Compute final winning index
                    let finalAngle = (self.rotation.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
                    let degreesPerSlice = 360.0 / Double(self.multipliers.count)
                    let angleUnderPointer = ((-90.0 - finalAngle).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
                    var index = Int(round(((angleUnderPointer + 90.0) / degreesPerSlice) - 0.5))
                    index = (index % self.multipliers.count + self.multipliers.count) % self.multipliers.count
                    let result = self.multipliers[index]
                    self.onResult(result)
                }
            }
            self.displayLinkProxy = proxy
            displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.onTick))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        private func renderWheelImage() {
            let view = ZStack {
                WheelShape(slices: multipliers.count)
                    .fill(.clear)
                    .overlay(FixedWheelSlices(multipliers: multipliers))
                    .frame(width: 260, height: 260)
            }
            if #available(iOS 16.0, *) {
                let renderer = ImageRenderer(content: view)
                renderer.scale = UITraitCollection.current.displayScale
                renderer.proposedSize = ProposedViewSize(CGSize(width: 260, height: 260))
                if let uiImage = renderer.uiImage {
                    renderedWheelImage = Image(uiImage: uiImage)
                    hasRenderedWheel = true
                }
            } else {
                // fallback for earlier iOS versions
                let controller = UIHostingController(rootView: view)
                controller.view.bounds = CGRect(x: 0, y: 0, width: 260, height: 260)
                let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
                let image = renderer.image { _ in
                    controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                renderedWheelImage = Image(uiImage: image)
                hasRenderedWheel = true
            }
        }
    }
    
    
    
    // MARK: - Wheel drawing helpers
    struct WheelShape: Shape {
        let slices: Int
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            let angle = 2 * .pi / CGFloat(slices)
            for i in 0..<slices {
                let start = CGFloat(i) * angle - .pi / 2
                let end = start + angle
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: Angle(radians: Double(start)), endAngle: Angle(radians: Double(end)), clockwise: false)
                path.closeSubpath()
            }
            return path
        }
    }
    
    /// New fixed-size wheel slices view for RouletteWheelView
    struct FixedWheelSlices: View {
        let multipliers: [Double]
        private let width: CGFloat = 260
        private let height: CGFloat = 260
        private let radius: CGFloat = 130
        private let center: CGPoint = CGPoint(x: 130, y: 130)
        
        var body: some View {
            ZStack {
                ForEach(0..<multipliers.count, id: \.self) { i in
                    let count = multipliers.count
                    let angle = 2 * .pi / Double(count)
                    let start = (-Double.pi/2) + (Double(i) * angle)
                    let end = start + angle
                    let mid = (start + end) / 2
                    let labelRadius = Double(radius) * 0.63
                    let labelX = Double(center.x) + cos(mid) * labelRadius
                    let labelY = Double(center.y) + sin(mid) * labelRadius
                    
                    Path { p in
                        p.move(to: center)
                        p.addArc(center: center,
                                 radius: radius,
                                 startAngle: Angle(radians: start),
                                 endAngle: Angle(radians: end),
                                 clockwise: false)
                        p.closeSubpath()
                    }
                    .fill(i % 2 == 0 ? Color.gray.opacity(0.8) : Color.blue.opacity(0.75))
                    
                    ZStack {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                        Text(String(format: "%.1fx", multipliers[i]))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .frame(width: 42, height: 20)
                    .position(x: labelX, y: labelY)
                    .rotationEffect(.degrees(0))
                }
            }
            .frame(width: width, height: height)
        }
    }
    
    
    struct WheelSlices: View {
        let multipliers: [Double]
        var body: some View {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let radius = size / 2
                let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                let count = multipliers.count
                let angle = 2 * .pi / Double(count)
                
                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        // Start at top (-90°) and move clockwise
                        let start = (-.pi/2) + (Double(i) * angle)
                        let end = start + angle
                        
                        // Slice shape
                        Path { p in
                            p.move(to: center)
                            p.addArc(center: center,
                                     radius: radius,
                                     startAngle: Angle(radians: start),
                                     endAngle: Angle(radians: end),
                                     clockwise: false)
                            p.closeSubpath()
                        }
                        .fill(i % 2 == 0 ? Color.gray.opacity(0.85) : Color.blue.opacity(0.8))
                        
                        // Label at slice center
                        let mid = (start + end) / 2
                        let labelRadius = radius * 0.63 // slightly closer to center to avoid clipping
                        let labelPoint = CGPoint(x: center.x + CGFloat(cos(mid)) * labelRadius,
                                                 y: center.y + CGFloat(sin(mid)) * labelRadius)
                        
                        ZStack {
                            // Background capsule for contrast
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                            Text(String(format: "%.1fx", multipliers[i]))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .frame(width: 42, height: 20)
                        .position(labelPoint)
                        // Keep text upright for readability
                        .rotationEffect(.degrees(0))
                    }
                }
            }
        }
    }
    struct TrianglePointer: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
    
    struct RouletteNumberWheelView: View {
        @Binding var isPresented: Bool
        var onResult: (_ pickedNumber: Int, _ winningNumber: Int, _ originalStake: Double) -> Void
        var onCommitPick: (_ originalMoney: Double) -> Void
        
        @State private var rotation: Double = 0
        @State private var isSpinning: Bool = false
        @State private var pickedText: String = ""
        @State private var hasCommittedPick: Bool = false
        @State private var originalStake: Double = 0.0
        
        // Replace SystemSoundID usage with only AVAudioPlayer pool
        @State private var clickPlayer: AVAudioPlayer? = nil
        @State private var playerPool: [AVAudioPlayer] = []
        @State private var poolIndex: Int = 0
        
        // Use a shared static to receive SFX volume from ContentView
        static var sharedSFXVolume: Float = 1.0
        
        // Timer-based animation properties
        //@State private var displayLinkTimer: Timer? = nil
        @State private var displayLink: CADisplayLink? = nil
        @State private var displayLinkProxy: DisplayLinkProxy? = nil
        @State private var spinStartTime: TimeInterval = 0
        @State private var spinDuration: TimeInterval = 1.5
        @State private var startRotation: Double = 0
        @State private var targetRotation: Double = 0
        @State private var prevPointerAngle: Double = 0
        @State private var nextSliceBoundary: Double = 0
        
        @State private var renderedWheelImage: Image? = nil
        @State private var hasRenderedWheel = false
        
        private func loadClickSound() {
            initPlayerPool()
        }
        private func playClick() {
            playLightClick()
        }
        
        private func initPlayerPool() {
            guard playerPool.isEmpty else { return }
            let urls: [URL?] = [
                Bundle.main.url(forResource: "chips-collide-1", withExtension: "wav"),
                Bundle.main.url(forResource: "click", withExtension: "wav")
            ]
            guard let url = urls.compactMap({ $0 }).first else { return }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<3 {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.volume = RouletteNumberWheelView.sharedSFXVolume
                    p.prepareToPlay()
                    pool.append(p)
                }
            }
            playerPool = pool
            poolIndex = 0
            if clickPlayer == nil { clickPlayer = pool.first }
        }
        private func playFromPool() {
            guard !playerPool.isEmpty else { return }
            poolIndex = (poolIndex + 1) % playerPool.count
            let p = playerPool[poolIndex]
            p.volume = RouletteNumberWheelView.sharedSFXVolume
            p.currentTime = 0
            p.play()
            clickPlayer = p
        }
        private func playLightClick() {
            AudioServicesPlaySystemSound(1104)
        }
        
        // Haptic feedback (light) with simple rate limiting
        // Removed per instructions
        
        private let numbers: [Int] = Array(1...20)
        
        class DisplayLinkProxy {
            var tick: (() -> Void)?
            @objc func onTick() {
                tick?()
            }
        }
        
        var body: some View {
            VStack(spacing: 16) {
                Spacer().frame(height: 8)
                Text("Number Spin")
                    .font(.title2).bold().foregroundColor(.green)
                
                ZStack {
                    // Wrap the number wheel with fixed size and drawingGroup, rotate the container
                    ZStack {
                        if let renderedWheelImage = renderedWheelImage {
                            renderedWheelImage
                                .resizable()
                                .frame(width: 260, height: 260)
                                .rotationEffect(.degrees(rotation))
                        } else {
                            WheelShape(slices: numbers.count)
                                .fill(.clear)
                                .overlay(FixedNumberWheelSlices(numbers: numbers))
                                .frame(width: 260, height: 260)
                        }
                    }
                    .drawingGroup()
                    
                    TrianglePointer()
                        .fill(Color.green.opacity(1.0))
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(180))
                        .offset(y: -130)
                        .shadow(radius: 1)
                }
                
                HStack(spacing: 8) {
                    TextField("Pick a number between 1 and 20", text: $pickedText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                        .disabled(isSpinning || hasCommittedPick)
                    Button("Confirm Pick") {
                        guard let pick = Int(pickedText), (1...20).contains(pick) else { return }
                        if !hasCommittedPick {
                            let stake = currentMoneyValue()
                            originalStake = stake
                            onCommitPick(stake)
                            hasCommittedPick = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(isSpinning || hasCommittedPick || !((Int(pickedText) ?? -1) >= 1 && (Int(pickedText) ?? -1) <= 20))
                }
                
                Button(isSpinning ? "Spinning..." : "Spin") {
                    guard !isSpinning else { return }
                    guard let pick = Int(pickedText), (1...20).contains(pick), hasCommittedPick else { return }
                    spinWheel(picked: pick)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .buttonStyle(PressScaleButtonStyle())
                .disabled(isSpinning)
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding()
            .presentationDetents([.medium])
            .onAppear {
                #if DEBUG
                print("[NumberWheel] onAppear")
                #endif
                loadClickSound()
                if !hasRenderedWheel {
                    renderWheelImage()
                }
                do {
                    try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    #if DEBUG
                    print("[NumberWheel] AVAudioSession error: \(error)")
                    #endif
                }
                let session = AVAudioSession.sharedInstance()
                #if DEBUG
                print("[NumberWheel] Category=\(session.category.rawValue), Mode=\(session.mode.rawValue), Output=\(session.currentRoute.outputs.map{ $0.portType.rawValue }.joined(separator: ", "))")
                #endif
                // Removed NotificationCenter observer for "TestClick" per instructions
            }
            .onDisappear {
                displayLink?.invalidate()
                displayLink = nil
                displayLinkProxy = nil
            }
        }
        
        // Helper to read current money from environment via NotificationCenter (simple bridge)
        private func currentMoneyValue() -> Double {
            // This placeholder allows the parent to pass in the value by closure; we simply return 0 here as we don't own the state.
            // Parent supplies the original money through onCommitPick.
            return 0.0
        }
        
        private func spinWheel(picked: Int) {
            isSpinning = true
            let degreesPerSlice = 360.0 / Double(numbers.count)
            let fullSpins = Double.random(in: 5.0...7.0)
            let randomOffset = Double.random(in: 0..<360)
            let delta = fullSpins * 360.0 + randomOffset
            startRotation = rotation
            targetRotation = rotation + delta
            spinDuration = 1.5
            spinStartTime = CACurrentMediaTime()
            
            let normalizeAngle: (Double) -> Double = { angle in
                let mod = angle.truncatingRemainder(dividingBy: 360)
                return mod < 0 ? mod + 360 : mod
            }
            func pointerAngle(for rotation: Double) -> Double {
                return normalizeAngle(-90.0 - rotation)
            }
            prevPointerAngle = pointerAngle(for: startRotation)
            nextSliceBoundary = degreesPerSlice * ceil(0 / degreesPerSlice) + degreesPerSlice
            
            displayLink?.invalidate()
            let proxy = DisplayLinkProxy()
            proxy.tick = {
                let now = CACurrentMediaTime()
                let t = min(1, (now - self.spinStartTime) / self.spinDuration)
                let eased = 1 - pow(1 - t, 3)
                self.rotation = self.startRotation + (self.targetRotation - self.startRotation) * eased
                
                let currentProgress = self.rotation - self.startRotation
                
                var clicksFired = 0
                while currentProgress >= self.nextSliceBoundary && clicksFired < 5 {
                    self.playClick()
                    self.nextSliceBoundary += degreesPerSlice
                    clicksFired += 1
                }
                
                if t >= 1.0 {
                    self.isSpinning = false
                    self.hasCommittedPick = false
                    self.displayLink?.invalidate()
                    self.displayLink = nil
                    
                    let finalAngle = (self.rotation.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
                    let angleUnderPointer = ((-90.0 - finalAngle).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
                    var index = Int(round(((angleUnderPointer + 90.0) / degreesPerSlice) - 0.5))
                    index = (index % self.numbers.count + self.numbers.count) % self.numbers.count
                    let winningNumber = self.numbers[index]
                    self.onResult(picked, winningNumber, self.originalStake)
                }
            }
            self.displayLinkProxy = proxy
            displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.onTick))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        private func renderWheelImage() {
            let view = ZStack {
                WheelShape(slices: numbers.count)
                    .fill(.clear)
                    .overlay(FixedNumberWheelSlices(numbers: numbers))
                    .frame(width: 260, height: 260)
            }
            if #available(iOS 16.0, *) {
                let renderer = ImageRenderer(content: view)
                renderer.scale = UITraitCollection.current.displayScale
                renderer.proposedSize = ProposedViewSize(CGSize(width: 260, height: 260))
                if let uiImage = renderer.uiImage {
                    renderedWheelImage = Image(uiImage: uiImage)
                    hasRenderedWheel = true
                }
            } else {
                // fallback for earlier iOS versions
                let controller = UIHostingController(rootView: view)
                controller.view.bounds = CGRect(x: 0, y: 0, width: 260, height: 260)
                let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
                let image = renderer.image { _ in
                    controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                renderedWheelImage = Image(uiImage: image)
                hasRenderedWheel = true
            }
        }
    }
    
    /// New fixed-size number wheel slices view for RouletteNumberWheelView
    struct FixedNumberWheelSlices: View {
        let numbers: [Int]
        private let width: CGFloat = 260
        private let height: CGFloat = 260
        private let radius: CGFloat = 130
        private let center: CGPoint = CGPoint(x: 130, y: 130)
        
        var body: some View {
            ZStack {
                ForEach(0..<numbers.count, id: \.self) { i in
                    let count = numbers.count
                    let angle = 2 * .pi / Double(count)
                    let start = (-Double.pi/2) + (Double(i) * angle)
                    let end = start + angle
                    let mid = (start + end) / 2
                    let labelRadius = Double(radius) * 0.63
                    let labelX = Double(center.x) + cos(mid) * labelRadius
                    let labelY = Double(center.y) + sin(mid) * labelRadius
                    
                    Path { p in
                        p.move(to: center)
                        p.addArc(center: center,
                                 radius: radius,
                                 startAngle: Angle(radians: start),
                                 endAngle: Angle(radians: end),
                                 clockwise: false)
                        p.closeSubpath()
                    }
                    .fill(i % 2 == 0 ? Color.gray.opacity(0.8) : Color.blue.opacity(0.75))
                    
                    ZStack {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                        Text("\(numbers[i])")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .frame(width: 42, height: 20)
                    .position(x: labelX, y: labelY)
                    .rotationEffect(.degrees(0))
                }
            }
            .frame(width: width, height: height)
        }
    }
    
    struct NumberWheelSlices: View {
        let numbers: [Int]
        var body: some View {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let radius = size / 2
                let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                let count = numbers.count
                let angle = 2 * .pi / Double(count)
                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        let start = (-.pi/2) + (Double(i) * angle)
                        let end = start + angle
                        Path { p in
                            p.move(to: center)
                            p.addArc(center: center, radius: radius, startAngle: Angle(radians: start), endAngle: Angle(radians: end), clockwise: false)
                            p.closeSubpath()
                        }
                        .fill(i % 2 == 0 ? Color.gray.opacity(0.85) : Color.blue.opacity(0.8))
                        
                        let mid = (start + end) / 2
                        let labelRadius = radius * 0.63
                        let labelPoint = CGPoint(x: center.x + CGFloat(cos(mid)) * labelRadius,
                                                 y: center.y + CGFloat(sin(mid)) * labelRadius)
                        ZStack {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                            Text("\(numbers[i])")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .frame(width: 42, height: 20)
                        .position(labelPoint)
                        .rotationEffect(.degrees(0))
                    }
                }
            }
        }
    }
    
    
    var body: some View {
        rootContent
    }
    
    private var rootContent: some View {
        
        
        
        // Break up the large view/modifier chain to help the type-checker further
        let base = ZStack {
            backgroundView
            mainButtonsGrid
        }
        let withBottomBanner = base
            .overlay(alignment: .bottom) { bottomBanner }
            .padding(.bottom, -40)

        // Erase type to simplify inference before adding many modifiers
        let allowsTouch = (!isAnimatingValue && !showingAmountPopup)
        let currentOpacity: Double = isAnimatingValue ? 0.6 : 1.0
        let step1 = withBottomBanner
            .allowsHitTesting(allowsTouch)
            .opacity(currentOpacity)
        let step2 = step1.animation(.easeInOut(duration: 0.2), value: isAnimatingValue)

        // Removed usage of ActiveSheetsModifier
        // Instead, add overlays and .sheet(item:) for activeSheet below
        
        let step3 = step2
            .overlay(alignment: .topLeading) { topLeftAccountPanel }
            .overlay(alignment: .leading) { settingsSlideOutPanel }
            .overlay(alignment: .leading) { settingsChevronHandle }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .roulette:
                    rouletteSheet
                case .roulette2:
                    roulette2Sheet
                case .settings:
                    NavigationStack {
                        SettingsSheetHost(section: $sheetSection, contentBuilder: { AnyView(self.settingsSheetContent) })
                            
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Close") { activeSheet = nil }
                                }
                            }
                    }
                case .addFriend:
                    AddFriendsView()
                }
            }

        // Replace multiple .overlay { ... } lines with a single overlay containing a ZStack with all conditional overlays
        let step4 = step3
            .overlay {
                ZStack {
                    if showingAmountPopup { amountPopup }
                    if showingProtectionConfirm { protectionOverlay }
                    if showingHighRiskConfirm { highRiskOverlay }
                    if showingLotteryConfirm { lotteryOverlay }
                    if showingHighRollerConfirm { highRollerOverlay }
                    if showingSuperHighRollerConfirm { superHighRollerOverlay }
                    if showingDollarForTwoConfirm { dollarForTwoOverlay }
                    if showingOfflineIncomePopup { offlineIncomeOverlay }
                    
                }
            }

        // ==== BEGIN REPLACED BLOCK ====
        let step5 = step4
            .onAppear {
                onAppearSetup()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    AppOpenAdManager.shared.tryToPresentAd()
                }
            }
            .onReceive(timer, perform: onTick)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RewardedAd_Ready"))) { _ in isRewardAdReady = true }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RewardedAd_Impression"))) { _ in
                #if DEBUG
                print("rewardedAd: impression recorded")
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RewardedAd_NotReady"))) { _ in isRewardAdReady = false }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppOpenAd_Impression"))) { _ in
                #if DEBUG
                print("app open ad: impression recorded")
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InterstitialAd_ShowNow"))) { _ in
                AdFrequencyController.shared.registerActionAndMaybeShowAd()
            }
            .onChange(of: economy.coins) { _, _ in
                Task { await updateUserEconomyToFirestore() }
            }
            .onChange(of: economy.money) { _, _ in
                Task { await updateUserEconomyToFirestore() }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        AppOpenAdManager.shared.tryToPresentAd()
                    }
                }
                
                else {
                    Task { @MainActor in
                        await economy.resetIncomeTimerIfNeeded()
                        await economy.save()
                    }
                }
            }
        
            .onChange(of: hasIncomePerMinute) { _, _ in
                updateCoinsPerSecond()
            }
            .onChange(of: hasIncomePer30s) { _, _ in
                updateCoinsPerSecond()
            }
            .onChange(of: hasIncomePer15s) { _, _ in
                updateCoinsPerSecond()
            }
            .onChange(of: hasIncomePer1s) { _, _ in
                updateCoinsPerSecond()
            }

            .sheet(isPresented: $showingUserInfo) {
                userInfoSheet
            }
        
            .sheet(isPresented: $showingUserInfo) {
                userInfoSheet
            }

        // Split the many onChange handlers into a lightweight wrapper to help the type-checker
        let step6 = step5
            .modifier(OnChangeGroup(
                onPersist: { persistState() },
                onApplyVolumesAndPersist: { applyVolumes(); persistState() },
                coins: economy.coins,
                money: economy.money,
                currentStreak: currentStreak,
                streakMultiplier: streakMultiplier,
                timeRemaining: timeRemaining,
                adCooldownRemaining: adCooldownRemaining,
                hasIncomePerMinute: hasIncomePerMinute,
                hasIncomePer30s: hasIncomePer30s,
                hasIncomePer15s: hasIncomePer15s,
                hasIncomePer1s: hasIncomePer1s,
                isStreakProtected: isStreakProtected,
                hasUsedProtectionForCurrentStreak: hasUsedProtectionForCurrentStreak,
                musicVolume: musicVolume,
                sfxVolume: sfxVolume,
                totalMoneyMade: totalMoneyMade,
                longestWinStreak: longestWinStreak,
                currentWinStreak: currentWinStreak,
                longestLossStreak: longestLossStreak,
                currentLossStreak: currentLossStreak,
                largestSingleGain: largestSingleGain,
                gamesPlayed: gamesPlayed,
                gamesWon: gamesWon,
                highestNetworth: highestNetworth
            ))

        return AnyView(
            Group {
                if auth.user == nil {
                    AuthView()
                } else {
                    step6
                }
            }
        )
        // ==== END REPLACED BLOCK ====
    }

    // Fallback User Info sheet to satisfy reference if not defined elsewhere
    private var userInfoSheet: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill").foregroundColor(.blue)
                    Text("Your Account").font(.title3).bold()
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "at").foregroundColor(.blue)
                        Text(auth.user?.email ?? "-")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "person").foregroundColor(.green)
                        Text("Username: \(storedUsername ?? "-")")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "person.text.rectangle").foregroundColor(.orange)
                        Text("Display name: \(storedDisplayName ?? auth.user?.displayName ?? "-")")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 6)

                Button("Close") { showingUserInfo = false }
                    .buttonStyle(.bordered)
                    .buttonStyle(PressScaleButtonStyle())
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .presentationDetents([.medium])
        .task {
            await loadStoredUsername()
        }
    }
}



private struct OnChangeGroup: ViewModifier {
    let onPersist: () -> Void
    let onApplyVolumesAndPersist: () -> Void

    // Values to observe
    var coins: Double
    var money: Double
    var currentStreak: Double
    var streakMultiplier: Double
    var timeRemaining: Int
    var adCooldownRemaining: Int
    var hasIncomePerMinute: Bool
    var hasIncomePer30s: Bool
    var hasIncomePer15s: Bool
    var hasIncomePer1s: Bool
    var isStreakProtected: Bool
    var hasUsedProtectionForCurrentStreak: Bool
    var musicVolume: Float
    var sfxVolume: Float
    var totalMoneyMade: Double
    var longestWinStreak: Int
    var currentWinStreak: Int
    var longestLossStreak: Int
    var currentLossStreak: Int
    var largestSingleGain: Double
    var gamesPlayed: Int
    var gamesWon: Int
    var highestNetworth: Double
    func body(content: Content) -> some View {
        var view = AnyView(content)
        
        // Break large chained expressions into multiple small overlays to help the type-checker
        view = AnyView(view.overlay(EmptyView().onChange(of: currentStreak) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: streakMultiplier) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: timeRemaining) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: adCooldownRemaining) { _, _ in onPersist() }))
        
        view = AnyView(view.overlay(EmptyView().onChange(of: hasIncomePerMinute) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: hasIncomePer30s) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: hasIncomePer15s) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: hasIncomePer1s) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: isStreakProtected) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: hasUsedProtectionForCurrentStreak) { _, _ in onPersist() }))
        
        view = AnyView(view.overlay(EmptyView().onChange(of: musicVolume) { _, _ in onApplyVolumesAndPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: sfxVolume) { _, _ in onApplyVolumesAndPersist() }))
        
        view = AnyView(view.overlay(EmptyView().onChange(of: coins) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: money) { _, _ in onPersist() }))
        
        view = AnyView(view.overlay(EmptyView().onChange(of: totalMoneyMade) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: longestWinStreak) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: currentWinStreak) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: longestLossStreak) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: currentLossStreak) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: largestSingleGain) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: gamesPlayed) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: gamesWon) { _, _ in onPersist() }))
        view = AnyView(view.overlay(EmptyView().onChange(of: highestNetworth) { _, _ in onPersist() }))
        
        return view
    }
}





// Insert the UserState struct here, as per instructions:



