import Foundation
import UserMessagingPlatform

/// Central gate for controlling how often interstitials are shown.
/// Call `registerActionAndMaybeShowAd()` from action button handlers.
@MainActor
final class AdFrequencyController {
    static let shared = AdFrequencyController()

    /// Show an interstitial every `threshold` actions.
    private let threshold: Int = 6

    /// Counts user actions since the last interstitial.
    private var actionCount: Int = 0
    private var lastInterstitialShownAt: Date? = nil
    private let minimumInterstitialInterval: TimeInterval = 20

    private init() {}

    /// Call this from each action button press.
    /// When the count reaches the threshold, attempt to present an interstitial and reset the counter.
    func registerActionAndMaybeShowAd() {
        if UserDefaults.standard.bool(forKey: "isPremiumActive") {
            return
        }

        guard ConsentInformation.shared.canRequestAds else { return }

        actionCount &+= 1
        if actionCount >= threshold {

            if let last = lastInterstitialShownAt,
               Date().timeIntervalSince(last) < minimumInterstitialInterval {
                actionCount = 0
                return
            }

            actionCount = 0
            lastInterstitialShownAt = Date()

            InterstitialAdManager.shared.loadIfNeeded()
            InterstitialAdManager.shared.presentIfAvailable()
        }
    }

    /// Optional: allow manual reset (e.g., on level start/end)
    func resetCounter() {
        actionCount = 0
    }
}
