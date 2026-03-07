//
//  ConsentManager.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 25.02.26.
//

import Foundation
import UIKit
import UserMessagingPlatform
import Combine


@MainActor
final class ConsentManager: ObservableObject {
    
    @Published private(set) var isPresentingConsentUI: Bool = false
    
    static let shared = ConsentManager()

    private init() {}

    /// Shows the "privacy options" form (this is the revocation link feature).
    func showPrivacyOptions() async {
        guard let vc = Self.topViewController() else { return }

        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: vc)
        } catch {
            // Optional: print("Failed to present privacy options: \(error)")
        }
    }
    
    func runConsentStartupFlow() async {
        
        guard let vc = Self.topViewController() else { return }

        let parameters = RequestParameters()   // (In some SDK versions this is UMPRequestParameters)
        isPresentingConsentUI = true
        defer { isPresentingConsentUI = false }
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
        } catch {
            // Optional: print("Consent info update failed: \(error)")
        }

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: vc)
            InterstitialAdManager.shared.loadIfNeeded()
            AppOpenAdManager.shared.loadIfNeeded()

        } catch {
            // Optional: print("Consent form failed: \(error)")
        }
    }

    private static func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

