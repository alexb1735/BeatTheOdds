import Foundation
import UserMessagingPlatform

/// Central gate for controlling how often interstitials are shown.
/// Call `registerActionAndMaybeShowAd()` from action button handlers.
@MainActor
final class AdFrequencyController {
    static let shared = AdFrequencyController()

    /// Show an interstitial every `threshold` actions.
    private let threshold: Int = 12

    /// Counts user actions since the last interstitial.
    private var actionCount: Int = 0

    private init() {}

    /// Call this from each action button press.
    /// When the count reaches the threshold, attempt to present an interstitial and reset the counter.
    func registerActionAndMaybeShowAd() {
        guard ConsentInformation.shared.canRequestAds else { return }

        actionCount &+= 1
        if actionCount >= threshold {
            actionCount = 0
            // Ensure an ad is ready or request one, then present if available.
            InterstitialAdManager.shared.loadIfNeeded()
            InterstitialAdManager.shared.presentIfAvailable()
        }
    }

    /// Optional: allow manual reset (e.g., on level start/end)
    func resetCounter() {
        actionCount = 0
    }
}
