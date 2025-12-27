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

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[Banner] Did receive ad")
        }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[Banner] Failed to load: \(error.localizedDescription)")
        }
        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            print("[Banner] Impression recorded")
        }
        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            print("[Banner] Click recorded")
        }
        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("[Banner] Will present screen")
        }
        func bannerViewWillDismissScreen(_ bannerView: BannerView) {
            print("[Banner] Will dismiss screen")
        }
        func bannerViewDidDismissScreen(_ bannerView: BannerView) {
            print("[Banner] Did dismiss screen")
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.activeKeyWindow?.rootViewController
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
            .contentShape(Rectangle())
            // Counteract the extra height so inter-button spacing doesn't grow
            // Previously min/max height was 52; now it's 64 (+12). Apply -6 on top and bottom.
            .padding(.vertical, -20)
            .buttonStyle(.plain)
    }
}

extension View {
    func pngButtonStyle() -> some View {
        self.modifier(PNGButtonBackground())
    }
}

struct TimerBadge: View {
    @Binding var timeRemaining: Int
    @Binding var coins: Double
    var reward: Double = 100.0
    @State private var flash = false
    
    var body: some View {
        
        
     
        
        
        
        VStack(alignment: .trailing, spacing: 2) {
            Text("$\(reward) will be added in:")
                .font(.caption2)
            
            Text(formatTime(timeRemaining))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(timeRemaining <= 10 ? .red : .white)
                .scaleEffect(flash ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: flash)
        }
        .padding(8)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .padding(12)
        .onChange(of: timeRemaining) {
            if timeRemaining == 3 * 60 * 60 {
                flash = true
                coins += reward
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
    @State private var coins: Double = 100.0
    @State private var money: Double = 0.0
    @State private var bet: Double = 10.0
    @State private var showAlert = false
    @State private var showingAmountPopup: Bool = false
    @State private var popupMode: PopupMode = .add
    @State private var amountText: String = ""
    @StateObject private var rewardedAdManager = RewardedAdManager()
    @State private var showingRoulette = false
    @State private var rouletteResultMultiplier: Double? = nil
    @State private var streakMultiplier: Double = 1.0
    @State private var isAnimatingValue = false
    
    @State private var currentStreak: Double = 1.0
    @State private var lastTotals: (coins: Double, money: Double) = (0.0, 0.0)
    
    @State private var showingRoulette2 = false
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
    
    // Reward sound player
    @State private var rewardPlayer: AVAudioPlayer? = nil
    
    // Deposit/withdraw sound player
    @State private var goldSackPlayer: AVAudioPlayer? = nil
    
    // Background music player
    @State private var backgroundPlayer: AVAudioPlayer? = nil
    
    // Settings popup and volumes
    @State private var showingSettings: Bool = false
    @State private var musicVolume: Float = 0.02
    @State private var sfxVolume: Float = 1.0
    
    // Consistent streak handling
    private func applyWin(to binding: Binding<Double>, baseChange: Double, isCoins: Bool) {
        // Apply current multiplier to winnings; first win uses current, then increment for next time
        let winnings = baseChange * streakMultiplier
        let target = binding.wrappedValue + winnings
        playRewardSound()
        animateValue(value: binding, to: target, isCoins: isCoins)
        
        // Increment multiplier AFTER applying this win so the next consecutive win uses +0.1 multiplier
        currentStreak += 0.1
        streakMultiplier = max(1.0, currentStreak)
        lastTotals = (coins, money)
    }
    
    private func applyLoss(to binding: Binding<Double>, lossAmount: Double, isCoins: Bool) {
        let target = max(0.0, binding.wrappedValue - lossAmount)
        animateValue(value: binding, to: target, isCoins: isCoins)
        
        if isStreakProtected {
            // Consume protection: keep current multiplier, then clear protection
            isStreakProtected = false
        } else {
            currentStreak = 1.0
            streakMultiplier = 1.0
            hasUsedProtectionForCurrentStreak = false
        }
        lastTotals = (coins, money)
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
            
            // Ease-out curve (casino feel)
            let t = Double(frame) / Double(steps)
            let eased = 1 - pow(1 - t, 3)
            
            let current = start + delta * eased
            value.wrappedValue = (current * 100).rounded() / 100
            
            if frame >= steps {
                timer.invalidate()
                value.wrappedValue = (target * 100).rounded() / 100
                
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
        if let url = Bundle.main.url(forResource: "Win sound", withExtension: "wav") {
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
            print("[BGMusic] two_left_socks.m4a not found in bundle")
            return
        }
        print("[BGMusic] URL:", url)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // loop indefinitely
            player.volume = musicVolume // reflect user-controlled music volume
            player.prepareToPlay()
            player.play()
            backgroundPlayer = player
        } catch {
            print("[BGMusic] failed to start:", error)
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
    
    // Popup mode for choosing between adding to coins or withdrawing from coins to cash
    enum PopupMode { case add, withdraw }
    
    
    
    var body: some View {
        
        
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .background(
                    Image("background1")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                )
            
            
            
            VStack(spacing: 0) { // changed from 8
                // Removed ScrollView as per instructions
                
                VStack(spacing: 0) { // changed from 6
                    
                    /*
                     Removed the protection button from scrollview as per instructions:
                     if currentStreak > 3 {
                     Button("Watch an ad to protect!") {
                     rewardedAdManager.showAd {
                     isStreakProtected = true
                     }
                     }
                     .buttonStyle(.borderedProminent)
                     .buttonStyle(PressScaleButtonStyle())
                     .tint(Color.black)
                     .foregroundStyle(isStreakProtected ? Color.yellow : Color.primary)
                     }
                     */
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            guard adCooldownRemaining == 0 else { return }
                            guard isRewardAdReady else {
                                // request another load
                                NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Load"), object: nil)
                                return
                            }
                            pauseBackgroundMusic()
                            rewardedAdManager.showAd {
                                let target = coins + 100.0
                                animateValue(value: $coins, to: target, isCoins: true)
                                // Start 10-minute cooldown (600 seconds)
                                adCooldownRemaining = 600
                                isRewardAdReady = false
                                NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Load"), object: nil)
                                resumeBackgroundMusic()
                            }
                        }) {
                            Image("watch_an_ad_to_earn_$100").resizable().scaledToFit()
                        }
                        .pngButtonStyle()
                        // Keep readable opacity even when disabled
                        .disabled(adCooldownRemaining > 0 || !isRewardAdReady)
                        .buttonStyle(.borderedProminent) // added
                        .buttonStyle(PressScaleButtonStyle())
                        .tint(Color.black)
                        // Make the label yellow when available; while disabled, keep it readable by explicitly setting foreground color
                        .foregroundColor(adCooldownRemaining > 0 ? .yellow : .yellow)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(glowTenX ? Color.green : Color.clear, lineWidth: 4))
                        Spacer()
                    }
                    .padding(.top, 0)
                    
                    HStack(spacing: 5) {
                        VStack(spacing: 5) {
                            VStack {
                                Button {
                                    if Bool.random() {
                                        // Win: increase by money (double -> +money) then apply streak multiplier
                                        let baseGain = money // doubling means net +money
                                        applyWin(to: $money, baseChange: baseGain, isCoins: false)
                                        glow($glowDoubleOrNothing)
                                    } else {
                                        // Loss: lose all current bet
                                        applyLoss(to: $money, lossAmount: money, isCoins: false)
                                    }
                                } label: {
                                    Image("double_or_nothing").resizable().scaledToFit()
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Button {
                                    showingHighRiskConfirm = true
                                } label: {
                                    Image("high_risk_high_reward").resizable().scaledToFit()
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Button {
                                    showingLotteryConfirm = true
                                } label: {
                                    Image("low_roller_lottery").resizable().scaledToFit()
                                }
                                .alert("Not enough funds!", isPresented: $showAlert) {
                                    Button("OK", role: .cancel) {}
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Button {
                                    showingHighRollerConfirm = true
                                } label: {
                                    Image("high_roller_lottery").resizable().scaledToFit()
                                }
                                .alert("Not enough funds!", isPresented: $showAlert) {
                                    Button("OK", role: .cancel) {}
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 5) {
                            VStack {
                                Button {
                                    showingSuperHighRollerConfirm = true
                                } label: {
                                    Image("super_high_roller_lottery").resizable().scaledToFit()
                                }
                                .alert("Not enough funds!", isPresented: $showAlert) {
                                    Button("OK", role: .cancel) {}
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Button {
                                    showingDollarForTwoConfirm = true
                                } label: {
                                    Image("$1_for_$2").resizable().scaledToFit()
                                }
                                .alert("Not enough funds!", isPresented: $showAlert) {
                                    Button("OK", role: .cancel) {}
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Button {
                                    showingRoulette = true
                                } label: {
                                    Image("multipliers_roulette").resizable().scaledToFit()
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Button {
                                    showingRoulette2 = true
                                } label: {
                                    Image("numbers_roulette").resizable().scaledToFit()
                                }
                                .pngButtonStyle()
                                .buttonStyle(.borderedProminent) // added
                                .buttonStyle(PressScaleButtonStyle())
                                .tint(Color.black)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                }
                .padding(.top, 4)
                
                Spacer(minLength: 16) // changed from 16
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity) // added
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.top, 140)
            .padding(.bottom, 8) // changed from 20
            
            // Removed bottom-anchored banner here as per instructions
//            BannerAdView(adUnitID: "ca-app-pub-9041707305654469/1334031800")
//                .frame(width: 320, height: 50)
//                .padding(.vertical, 8)
        }
        .overlay(alignment: .bottom) {
            BannerAdView(adUnitID: "ca-app-pub-9041707305654469/1334031800")
                .frame(width: 320, height: 50)
                .padding(.bottom, 8)
        }
        .allowsHitTesting(!isAnimatingValue && !showingAmountPopup)
        .opacity(isAnimatingValue ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isAnimatingValue)
        .animation(.none, value: showingAmountPopup)
        .padding(.bottom, 8)
        .onAppear {
            lastTotals = (coins, money)
            if currentStreak < 1.0 { currentStreak = 1.0 }
            streakMultiplier = max(1.0, currentStreak)
            // Try to preload an ad; RewardedAdManager should post readiness via NotificationCenter or callbacks
            NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Load"), object: nil)
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                // Ignore audio session errors for reward sound
            }
            startBackgroundMusic()
            applyVolumes()
        }
        .onDisappear {
            stopBackgroundMusic()
        }
        .sheet(isPresented: $showingRoulette) {
            RouletteWheelView(isPresented: $showingRoulette) { multiplier in
                let originalMoney = money
                let baseComputed = originalMoney * multiplier
                if multiplier > 1.0 {
                    let netGain = baseComputed - originalMoney
                    applyWin(to: $money, baseChange: netGain, isCoins: false)
                    glow($glowMultiplierRoulette)
                } else if multiplier < 1.0 {
                    let loss = originalMoney - baseComputed
                    applyLoss(to: $money, lossAmount: loss, isCoins: false)
                } else {
                    // multiplier == 1.0, treat as no change; if protected, keep streak and consume protection; otherwise reset
                    if isStreakProtected {
                        isStreakProtected = false
                    } else {
                        currentStreak = 1.0
                        streakMultiplier = 1.0
                        hasUsedProtectionForCurrentStreak = false
                    }
                    animateValue(value: $money, to: originalMoney, isCoins: false)
                }
                lastTotals = (coins, money)
            }
        }
        .sheet(isPresented: $showingRoulette2) {
            RouletteNumberWheelView(isPresented: $showingRoulette2) { pickedNumber, winningNumber, originalStake in
                // Determine result after wheel stops
                if pickedNumber == winningNumber {
                    // Win: set money to exactly (original * 20 * multiplier)
                    let targetFinal = originalStake * 20.0 * streakMultiplier
                    playRewardSound()
                    animateValue(value: $money, to: targetFinal, isCoins: false)
                    // Advance streak after a win
                    currentStreak += 0.1
                    streakMultiplier = max(1.0, currentStreak)
                    lastTotals = (coins, money)
                    glow($glowNumbersRoulette)
                } else {
                    // Loss: set money to 0 after result is known
                    animateValue(value: $money, to: 0.0, isCoins: false)
                    if isStreakProtected {
                        // Consume protection: keep current multiplier, then clear protection
                        isStreakProtected = false
                    } else {
                        currentStreak = 1.0
                        streakMultiplier = 1.0
                        hasUsedProtectionForCurrentStreak = false
                    }
                    lastTotals = (coins, money)
                }
            } onCommitPick: { original in
                // Do not zero the bet here anymore; only store original stake
                roulette2OriginalMoney = original
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.none, value: showingAmountPopup)
        .overlay {
            if showingAmountPopup {
                ZStack {
                    GeometryReader { proxy in
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .transition(.opacity)
                        VStack(spacing: 16) {
                            Text(popupMode == .add ? "Deposit amount:" : "Withdrawal amount:")
                                .font(.headline)
                            TextField("Enter amount", text: $amountText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            HStack {
                                Button("Close") {
                                    showingAmountPopup = false
                                }
                                .buttonStyle(.bordered)
                                .buttonStyle(PressScaleButtonStyle())
                                
                                Button("Confirm") {
                                    let amount = Double(amountText) ?? 0.0
                                    guard amount > 0.0 else { showingAmountPopup = false; return }
                                    switch popupMode {
                                    case .add:
                                        // Deposit from bet (money) to coins; require enough in money
                                        if amount > money {
                                            showAlert = true
                                            // keep popup open to let user adjust amount
                                            return
                                        }
                                        let coinsTarget = coins + amount
                                        let moneyTarget = money - amount
                                        animateValue(value: $coins, to: coinsTarget, isCoins: true)
                                        animateValue(value: $money, to: moneyTarget, isCoins: false)
                                        playGoldSackSound()
                                        showingAmountPopup = false
                                    case .withdraw:
                                        // Withdraw from coins to bet (money); require enough in coins
                                        if amount > coins {
                                            showAlert = true
                                            // keep popup open to let user adjust amount
                                            return
                                        }
                                        let coinsTarget = coins - amount
                                        let moneyTarget = money + amount
                                        animateValue(value: $coins, to: coinsTarget, isCoins: true)
                                        animateValue(value: $money, to: moneyTarget, isCoins: false)
                                        playGoldSackSound()
                                        showingAmountPopup = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonStyle(PressScaleButtonStyle())
                                .disabled(Double(amountText) == nil || (Double(amountText) ?? 0.0) <= 0.0)
                            }
                        }
                        .padding()
                        .frame(maxWidth: 320)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .ignoresSafeArea(.keyboard) // ensure popup ignores keyboard safe area
                    }
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .overlay(alignment: .topLeading) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bank account: $\(formatNumber(coins))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isAnimatingCoinsIncrease ? .green : (isAnimatingCoinsDecrease ? .red : .white))
                    
                    Text("Your bet: $\(formatNumber(money))")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(isAnimatingMoneyIncrease ? .green : (isAnimatingMoneyDecrease ? .red : .white))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Withdraw") {
                            popupMode = .withdraw
                            amountText = ""
                            showingAmountPopup = true
                        }
                        
                        .buttonStyle(.borderedProminent)
                        .buttonStyle(PressScaleButtonStyle())
                        
                        
                        Button("Deposit") {
                            popupMode = .add
                            amountText = ""
                            showingAmountPopup = true
                        }
                       
                        .buttonStyle(.borderedProminent)
                        .buttonStyle(PressScaleButtonStyle())
                    }
                    .padding(.top, 6)
                }
                .padding(10)
                .background(Color.black.opacity(0))
                .cornerRadius(10)
                .padding(.leading, 12)
                .padding(.top, 8)
                .allowsHitTesting(true)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$100 will be added in:")
                            .font(.caption2)
                        Text(formatTime(timeRemaining))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black)
                    .cornerRadius(8)
                    
                    HStack(spacing: 6) {
                        Text("Current multiplier: \(String(format: "%.1f", streakMultiplier))")
                            .font(.caption)
                            .foregroundColor(isStreakProtected ? .yellow : .white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black)
                    .cornerRadius(8)
                    
                    if streakMultiplier > 1.4 && !hasUsedProtectionForCurrentStreak {
                        Button(action: {
                            showingProtectionConfirm = true
                        }) {
                            Text("watch ad to protect!")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 12)
                .padding(.top, 8)
            }
            .zIndex(1000)
            .allowsHitTesting(true)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 12)
                .padding(.bottom, 68) // changed from 70 as per instructions
            }
            .allowsHitTesting(true)
        }
        .overlay {
            if showingProtectionConfirm {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingProtectionConfirm = false }
                    VStack(spacing: 12) {
                        Text("watch an ad to protect your multiplier from resetting on your next loss?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        HStack(spacing: 12) {
                            Button("Close") {
                                showingProtectionConfirm = false
                            }
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
                            .pngButtonStyle()
                            .buttonStyle(.borderedProminent)
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding()
                    .frame(maxWidth: 320)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .zIndex(9999)
            }
        }
        .overlay {
            if showingHighRiskConfirm {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingHighRiskConfirm = false }
                    VStack(spacing: 12) {
                        Text("90% Chance to divide your bet by 10, 10% chance to multiply your bet by 10!")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        HStack(spacing: 12) {
                            Button("Not right now.") {
                                showingHighRiskConfirm = false
                            }
                            .buttonStyle(.bordered)
                            .buttonStyle(PressScaleButtonStyle())
                            Button("Let's do it!") {
                                // Execute original high risk, high reward logic
                                let oneInTen = Int.random(in: 1...10)
                                if oneInTen == 1 {
                                    let baseGain = money * 9.0
                                    applyWin(to: $money, baseChange: baseGain, isCoins: false)
                                    glow($glowTenX)
                                } else {
                                    let loss = money * 0.9
                                    applyLoss(to: $money, lossAmount: loss, isCoins: false)
                                }
                                showingHighRiskConfirm = false
                            }
                            
                            .buttonStyle(.borderedProminent)
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding()
                    .frame(maxWidth: 320)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .zIndex(9999)
            }
        }
        .overlay {
            if showingLotteryConfirm {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingLotteryConfirm = false }
                    VStack(spacing: 12) {
                        Text("Spend $100 for the 2% chance to win $5000?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        HStack(spacing: 12) {
                            Button("Not right now.") {
                                showingLotteryConfirm = false
                            }
                            .buttonStyle(.bordered)
                            .buttonStyle(PressScaleButtonStyle())
                            Button("Let's do it!") {
                                // Execute original Lottery logic
                                if coins >= 100.0 {
                                    let twopercent = Int.random(in: 1...50)
                                    if twopercent == 1 {
                                        applyWin(to: $coins, baseChange: 5000.0, isCoins: true)
                                        glow($glowTwoPercent)
                                    } else {
                                        applyLoss(to: $coins, lossAmount: 100.0, isCoins: true)
                                    }
                                } else {
                                    showAlert = true
                                }
                                showingLotteryConfirm = false
                            }
                            
                            .buttonStyle(.borderedProminent)
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding()
                    .frame(maxWidth: 320)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .zIndex(9999)
            }
        }
        .overlay {
            if showingHighRollerConfirm {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingHighRollerConfirm = false }
                    VStack(spacing: 12) {
                        Text("Spend $250 for the 10% chance of winning $2,500?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        HStack(spacing: 12) {
                            Button("Not right now") {
                                showingHighRollerConfirm = false
                            }
                            .buttonStyle(.bordered)
                            .buttonStyle(PressScaleButtonStyle())
                            Button("Let's do it!") {
                                // Execute original $250 / 10% lottery logic
                                if coins >= 250.0 {
                                    let tenpercent = Int.random(in: 1...10)
                                    if tenpercent == 1 {
                                        applyWin(to: $coins, baseChange: 2500.0, isCoins: true)
                                        glow($glowTenPercent)
                                    } else {
                                        applyLoss(to: $coins, lossAmount: 250.0, isCoins: true)
                                    }
                                } else {
                                    showAlert = true
                                }
                                showingHighRollerConfirm = false
                            }
                            
                            .buttonStyle(.borderedProminent)
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding()
                    .frame(maxWidth: 320)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .zIndex(9999)
            }
        }
        .overlay {
            if showingSuperHighRollerConfirm {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingSuperHighRollerConfirm = false }
                    VStack(spacing: 12) {
                        Text("Spend $100 for the 1% chance of winning $10,000?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        HStack(spacing: 12) {
                            Button("Not right now") {
                                showingSuperHighRollerConfirm = false
                            }
                            .buttonStyle(.bordered)
                            .buttonStyle(PressScaleButtonStyle())
                            Button("Let's do it!") {
                                // Execute original 1% / $100 logic
                                if coins >= 100.0 {
                                    let onepercent = Int.random(in: 1...100)
                                    if onepercent == 1 {
                                        applyWin(to: $coins, baseChange: 10000.0, isCoins: true)
                                        glow($glowOnePercent)
                                    } else {
                                        applyLoss(to: $coins, lossAmount: 100.0, isCoins: true)
                                    }
                                } else {
                                    showAlert = true
                                }
                                showingSuperHighRollerConfirm = false
                            }
                            
                            .buttonStyle(.borderedProminent)
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding()
                    .frame(maxWidth: 320)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .zIndex(9999)
            }
        }
        .overlay {
            if showingDollarForTwoConfirm {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingDollarForTwoConfirm = false }
                    VStack(spacing: 12) {
                        Text("Spend $1 for the 50% chance of winning $2?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        HStack(spacing: 12) {
                            Button("Not right now.") {
                                showingDollarForTwoConfirm = false
                            }
                            .buttonStyle(.bordered)
                            .buttonStyle(PressScaleButtonStyle())
                            Button("Let's do it!") {
                                // Execute original 50% logic
                                if coins >= 1.0 {
                                    let fiftypercent = Int.random(in: 1...2)
                                    if fiftypercent == 1 {
                                        applyWin(to: $coins, baseChange: 1.0, isCoins: true)
                                        glow($glowFiftyPercent)
                                    } else {
                                        applyLoss(to: $coins, lossAmount: 1.0, isCoins: true)
                                    }
                                } else {
                                    showAlert = true
                                }
                                showingDollarForTwoConfirm = false
                            }
                           
                            .buttonStyle(.borderedProminent)
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding()
                    .frame(maxWidth: 320)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .zIndex(9999)
            }
        }
        // Updated settings overlay with centered alignment and black background
        .overlay {
            if showingSettings {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingSettings = false }
                    VStack(alignment: .center, spacing: 16) {
                        HStack {
                            Spacer()
                            Button(action: { showingSettings = false }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.primary)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        VStack(alignment: .center, spacing: 8) {
                            Text("Music")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Slider(value: Binding(get: { Double(musicVolume) }, set: { newVal in
                                musicVolume = Float(newVal)
                                applyVolumes()
                            }), in: 0...1)
                            .frame(maxWidth: .infinity)
                        }
                        VStack(alignment: .center, spacing: 8) {
                            Text("Sound effects")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Slider(value: Binding(get: { Double(sfxVolume) }, set: { newVal in
                                sfxVolume = Float(newVal)
                                applyVolumes()
                            }), in: 0...1)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 340)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .zIndex(10000)
            }
        }
        
        
        .onReceive(timer) { _ in
            if adCooldownRemaining > 0 {
                adCooldownRemaining = max(0, adCooldownRemaining - 1)
            }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                
                let target = coins + 100.0
                animateValue(value: $coins, to: target, isCoins: true)
                
                timeRemaining = 3 * 60 * 60
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RewardedAd_Ready"))) { _ in
            isRewardAdReady = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RewardedAd_NotReady"))) { _ in
            isRewardAdReady = false
        }
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
                Text("Roulette")
                    .font(.title2)
                    .bold()
                    .tint(.orange)
                
                
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
                        .fill(Color.blue.opacity(1.0))
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
                print("[Wheel] onAppear")
                loadClickSound()
                if !hasRenderedWheel {
                    renderWheelImage()
                }
                do {
                    try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("[Wheel] AVAudioSession error: \(error)")
                }
                let session = AVAudioSession.sharedInstance()
                print("[Wheel] Category=\(session.category.rawValue), Mode=\(session.mode.rawValue), Output=\(session.currentRoute.outputs.map{ $0.portType.rawValue }.joined(separator: ", "))")
                NotificationCenter.default.addObserver(forName: NSNotification.Name("TestClick"), object: nil, queue: .main) { _ in
                    print("[Wheel] TestClick notification -> playClick()")
                    playClick()
                }
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
                renderer.scale = UIScreen.main.traitCollection.displayScale
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
    private struct WheelShape: Shape {
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
    private struct FixedWheelSlices: View {
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
                    .fill(i % 2 == 0 ? Color.black : Color.red)
                    
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
    
    
    private struct WheelSlices: View {
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
                        .fill(i % 2 == 0 ? Color.black : Color.red)
                        
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
    private struct TrianglePointer: Shape {
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
                Text("Roulette 2")
                    .font(.title2).bold().tint(.orange)
                
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
                        .fill(Color.blue.opacity(1.0))
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
                print("[NumberWheel] onAppear")
                loadClickSound()
                if !hasRenderedWheel {
                    renderWheelImage()
                }
                do {
                    try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("[NumberWheel] AVAudioSession error: \(error)")
                }
                let session = AVAudioSession.sharedInstance()
                print("[NumberWheel] Category=\(session.category.rawValue), Mode=\(session.mode.rawValue), Output=\(session.currentRoute.outputs.map{ $0.portType.rawValue }.joined(separator: ", "))")
                NotificationCenter.default.addObserver(forName: NSNotification.Name("TestClick"), object: nil, queue: .main) { _ in
                    print("[NumberWheel] TestClick notification -> playClick()")
                    playClick()
                }
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
                renderer.scale = UIScreen.main.traitCollection.displayScale
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
    private struct FixedNumberWheelSlices: View {
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
                    .fill(i % 2 == 0 ? Color.black : Color.red)
                    
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
    
    private struct NumberWheelSlices: View {
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
                        .fill(i % 2 == 0 ? Color.black : Color.red)
                        
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
    
    
}
// Append the preview block outside the ContentView type:
#Preview {
    ContentView()
}

