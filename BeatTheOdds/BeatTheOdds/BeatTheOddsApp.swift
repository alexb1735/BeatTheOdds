import SwiftUI
import GoogleMobileAds
import FirebaseAuth
import Combine

@main
struct BeatTheOddsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var auth = AuthManager()
    @StateObject private var economy = EconomyStore()
    @StateObject private var upgrades = UpgradesStore()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let mobileAds = MobileAds.shared
        mobileAds.requestConfiguration.testDeviceIdentifiers = [
            "ced985bc4d7c830e9b85b62e51dbed02"
        ]
        mobileAds.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(economy)
                .environmentObject(upgrades)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                AppOpenAdManager.shared.loadIfNeeded()
                InterstitialAdManager.shared.loadIfNeeded()
                // Presentation of App Open Ad is handled by AppOpenAdManager's foreground observer.
            }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var economy: EconomyStore
    @EnvironmentObject var upgrades: UpgradesStore

    var body: some View {
        Group {
            if auth.user != nil {
                ContentView()
                    .onAppear { economy.start() }
                    .onAppear { upgrades.start() }
                    .onDisappear { economy.stop() }
                    .onDisappear { upgrades.stop() }
            } else {
                AuthView()
                    .onAppear { economy.stop() }
                    .onAppear { upgrades.stop() }
            }
        }
    }
}

