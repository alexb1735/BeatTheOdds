//
//  InterstitialAdManager.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 01.03.26.
//

import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class InterstitialAdManager: NSObject {
    static let shared = InterstitialAdManager()

    // Use test ID while developing. Replace with your real Interstitial ad unit ID before release.
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"

    private var interstitial: InterstitialAd?
    private var isLoading = false
    private var lastPresentAttempt: Date? = nil

    private override init() {}

    // MARK: - Load
    func loadIfNeeded() {
        guard ConsentInformation.shared.canRequestAds else {
            return
        }
        guard !isLoading, interstitial == nil else { return }

        isLoading = true
        let request = Request()

        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, err in
            guard let self else { return }
            self.isLoading = false

            if let err {
                print("Interstitial load error: \(err.localizedDescription)")
                self.interstitial = nil
                return
            }

            self.interstitial = ad
            self.interstitial?.fullScreenContentDelegate = self
            print("Interstitial loaded")
        }
    }

    // MARK: - Present
    func presentIfAvailable() {
        guard ConsentInformation.shared.canRequestAds else {
            return
        }
        
        if let last = lastPresentAttempt, Date().timeIntervalSince(last) < 1.0 { return }
        lastPresentAttempt = Date()
        
        guard let ad = interstitial else {
            loadIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.presentIfAvailable()
            }
            return
        }

        guard let topVC = Self.topViewController() else {
            return
        }

        // Some SDK versions provide canPresent; if yours supports it, keep this block.
        // If you get a compile error here, tell me your exact error and I’ll adjust to your SDK signature.
        do {
            try ad.canPresent(from: topVC)
        } catch {
            interstitial = nil
            loadIfNeeded()
            return
        }

        print("Interstitial: presenting")
        ad.present(from: topVC)
        interstitial = nil // single-use; Google recommends dropping reference after presenting
    }

    private static func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        var top = root
        while true {
            if let presented = top.presentedViewController {
                top = presented
                continue
            }
            if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
                top = visible
                continue
            }
            if let tab = top as? UITabBarController, let selected = tab.selectedViewController {
                top = selected
                continue
            }
            break
        }
        return top
    }
}

extension InterstitialAdManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
        loadIfNeeded()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        loadIfNeeded()
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("impression recorded")
    }
}
