//
//  rewardAd.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 28.12.25.
//
import Foundation
import SwiftUI
import GoogleMobileAds
import Combine

final class RewardedAdManager: NSObject, ObservableObject {

    @Published var isAdReady = false
    private var rewardedAd: RewardedAd?

    // Test Rewarded Ad Unit ID
#if DEBUG
private let adUnitID = "ca-app-pub-3940256099942544/1712485313"
#else
private let adUnitID = "ca-app-pub-9041707305654469/7422047562"
#endif

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleLoadRequest), name: NSNotification.Name("RewardedAd_Load"), object: nil)
        loadAd()
    }

    @objc private func handleLoadRequest() {
        loadAd()
    }

    func loadAd() {
        // Mark not ready while loading and notify UI
        isAdReady = false
        NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_NotReady"), object: nil)

        // Clear any previous ad reference
        rewardedAd = nil

        let request = Request()
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            if let error = error {
                print("Rewarded ad failed to load: \(error.localizedDescription)")
                self.isAdReady = false
                NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_NotReady"), object: nil)
                return
            }
            self.rewardedAd = ad
            self.isAdReady = true
            NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_Ready"), object: nil)
        }
    }

    func showAd(onReward: @escaping () -> Void) {
        guard let rewardedAd = rewardedAd, isAdReady else {
            print("Ad not ready")
            NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_NotReady"), object: nil)
            loadAd()
            return
        }

        guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController else {
            print("No root view controller found")
            return
        }

        // Set delegate to detect dismissal and failures
        rewardedAd.fullScreenContentDelegate = self

        // Not ready until we load the next one
        isAdReady = false
        NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_NotReady"), object: nil)

        rewardedAd.present(from: rootVC) {
            onReward()
        }
    }
}

extension RewardedAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // After dismissal, clear and load the next ad
        self.rewardedAd = nil
        self.isAdReady = false
        NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_NotReady"), object: nil)
        self.loadAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Rewarded ad failed to present: \(error.localizedDescription)")
        self.rewardedAd = nil
        self.isAdReady = false
        NotificationCenter.default.post(name: NSNotification.Name("RewardedAd_NotReady"), object: nil)
        self.loadAd()
    }
}
