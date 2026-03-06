import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

final class AppOpenAdManager: NSObject {
  
  static let shared = AppOpenAdManager()
  
  private let adUnitID = "ca-app-pub-9041707305654469/1313227723"
  
  private var appOpenAd: GADAppOpenAd?
  private var isLoading: Bool = false
  private var isShowingAd: Bool = false
  private var loadDate: Date?
  
  private override init() {
    super.init()
  }
  
  /// Loads an App Open Ad if one isn't already loaded or loading.
  public func loadIfNeeded() {
    if isAdAvailable || isLoading {
      return
    }
    
    isLoading = true
    let request = GADRequest()
    
    if AppOpenAdManager.shouldRequestNonPersonalizedAds() {
      let extras = GADExtras()
      extras.additionalParameters = ["npa": "1"]
      request.register(extras)
    }
    
    GADAppOpenAd.load(
      withAdUnitID: adUnitID,
      request: request,
      orientation: UIInterfaceOrientation.portrait
    ) { [weak self] (ad, error) in
      guard let self = self else { return }
      self.isLoading = false
      if let error = error {
        self.appOpenAd = nil
        self.loadDate = nil
        // Could log error here if needed
        return
      }
      self.appOpenAd = ad
      self.loadDate = Date()
    }
  }
  
  /// Returns true if an app open ad is available and fresh (loaded within 4 hours).
  private var isAdAvailable: Bool {
    guard let loadTime = loadDate else { return false }
    let timeInterval = Date().timeIntervalSince(loadTime)
    return appOpenAd != nil && timeInterval < 4 * 60 * 60
  }
  
  /// Attempts to present the ad if available and not currently showing.
  /// If not available, triggers a load.
  public func tryToPresentAd() {
    guard !isShowingAd, isAdAvailable, let ad = appOpenAd else {
      loadIfNeeded()
      return
    }
    
    guard let topVC = topViewController() else {
      // Cannot present without a valid top view controller
      return
    }
    
    ad.fullScreenContentDelegate = self
    ad.present(fromRootViewController: topVC)
    isShowingAd = true
  }
  
  /// Returns the currently visible top view controller from the key window.
  private func topViewController() -> UIViewController? {
    let keyWindow: UIWindow?
    if #available(iOS 13.0, *) {
      keyWindow = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })
    } else {
      keyWindow = UIApplication.shared.keyWindow
    }
    
    guard var topVC = keyWindow?.rootViewController else {
      return nil
    }
    
    while let presented = topVC.presentedViewController {
      topVC = presented
    }
    return topVC
  }
}

// MARK: - GADFullScreenContentDelegate

extension AppOpenAdManager: GADFullScreenContentDelegate {
  
  func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    appOpenAd = nil
    isShowingAd = false
    loadIfNeeded()
  }
  
  func ad(_ ad: GADFullScreenPresentingAd,
          didFailToPresentFullScreenContentWithError error: Error) {
    appOpenAd = nil
    isShowingAd = false
    loadIfNeeded()
  }
  
  func adDidPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    // No action needed on present
  }
}

// MARK: - Non-Personalized Ads Helper

extension AppOpenAdManager {
  /// Determines whether to request non-personalized ads based on UMP consent status.
  ///
  /// This method checks if the user consent for personalized ads is granted.
  /// If consent is required but not granted, or if consent status is unknown,
  /// it requests non-personalized ads as a conservative default.
  ///
  /// Integrators should refine this logic according to their UMP version and app logic.
  static func shouldRequestNonPersonalizedAds() -> Bool {
    let consentInfo = ConsentInformation.shared
    
    switch consentInfo.consentStatus {
    case .personalized:
      // Personalized ads consent granted
      return false
    case .nonPersonalized:
      // User has given non-personalized consent explicitly
      return true
    case .unknown:
      // Consent unknown, prefer non-personalized ads by default for safety
      return true
    @unknown default:
      // Future cases, default to non-personalized ads
      return true
    }
  }
}
