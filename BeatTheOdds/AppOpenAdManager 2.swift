import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

final class AppOpenAdManager: NSObject {
  
  static let shared = AppOpenAdManager()
  
  private let adUnitID = "ca-app-pub-3940256099942544/5575463023"
  
  private var appOpenAd: AppOpenAd?
  private var isLoading: Bool = false
  private var isShowingAd: Bool = false
  private var loadDate: Date?
  private var hasShownAdThisForeground = false
    
  private var lastPresentAttempt: Date?
  
  private override init() {
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
  }
  
  /// Call this at app launch (e.g., in App/Scene initialization) to preload and try to present as early as possible.
    public func start() {
        if UserDefaults.standard.bool(forKey: "isPremiumActive") {
            return
        }
        loadIfNeeded()
    }
  @objc private func appWillEnterForeground() {
    // Reset state on new foreground session and try once
    hasShownAdThisForeground = false
    // Only try to present once per foreground session
    tryToPresentAd()
  }

  @objc private func appDidEnterBackground() {
    // Reset the flag to allow showing on next foreground
    hasShownAdThisForeground = false
  }
  
  /// Attempts to present shortly after app launch, retrying for a short window without blocking UI.
 
  
  /// Loads an App Open Ad if one isn't already loaded or loading.
  public func loadIfNeeded() {
      if UserDefaults.standard.bool(forKey: "isPremiumActive") {
          return
      }
      guard ConsentInformation.shared.canRequestAds else {
          print("AppOpen: cannot request ads yet (consent not ready)")
          return
      }
      
    if isAdAvailable || isLoading {
      return
    }
    
    isLoading = true
    let request = Request()
    
    if AppOpenAdManager.shouldRequestNonPersonalizedAds() {
      let extras = Extras()
      extras.additionalParameters = ["npa": "1"]
      request.register(extras)
    }
    
    AppOpenAd.load(with: adUnitID, request: request) { [weak self] (ad: AppOpenAd?, error: Error?) in
      guard let self = self else { return }
      self.isLoading = false
        if let error = error {
          print("AppOpen load error: \(error.localizedDescription)")
          self.appOpenAd = nil
          self.loadDate = nil
          return
        }
        print("AppOpen loaded")
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
      if UserDefaults.standard.bool(forKey: "isPremiumActive") {
          return
      }
      guard ConsentInformation.shared.canRequestAds else {
          print("AppOpen: cannot present yet (consent not ready)")
          return
      }
      print("AppOpen: tryToPresentAd (canRequestAds=\(ConsentInformation.shared.canRequestAds))")
      
      // Only present once per foreground session
      if hasShownAdThisForeground {
          return
      }
      
      // Don’t stack fullscreen UIs (very important if consent form is up)
      
      if let last = lastPresentAttempt, Date().timeIntervalSince(last) < 2.0 {
          return
      }
      lastPresentAttempt = Date()
      
      if ConsentManager.shared.isPresentingConsentUI {
          print("AppOpen: skipping (consent UI presenting)")
          return
      }
      
      guard !isShowingAd else { return }

      // If no ad, load and exit
      guard let ad = appOpenAd else {
          print("AppOpen: no cached ad yet → loading")
          loadIfNeeded()
          return
      }

      guard let topVC = topViewController() else {
          print("AppOpen: no top VC")
          return
      }

      do {
          try ad.canPresent(from: topVC)
      } catch {
          print("AppOpen: cannot present -> \(error.localizedDescription)")
          appOpenAd = nil
          loadIfNeeded()
          return
      }

      ad.fullScreenContentDelegate = self
      print("AppOpen: presenting")
      ad.present(from: topVC)
      hasShownAdThisForeground = true
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

// MARK: - FullScreenContentDelegate

extension AppOpenAdManager: FullScreenContentDelegate {
    
    internal func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        appOpenAd = nil
        isShowingAd = false
        loadIfNeeded()
    }
    
    internal func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        appOpenAd = nil
        isShowingAd = false
        loadIfNeeded()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("AppOpen: will present")
        isShowingAd = true
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
    case .obtained:
      // User provided consent; allow personalized ads
      return false
    case .required:
      // Consent required but not obtained; request non-personalized ads
      return true
    case .notRequired:
      // Consent not required in this region; allow personalized ads
      return false
    case .unknown:
      // Consent unknown, request non-personalized ads to be safe
      return true
    @unknown default:
      // Be conservative by default
      return true
    }
  }
}
