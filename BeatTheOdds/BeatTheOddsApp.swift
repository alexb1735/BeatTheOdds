//
//  BeatTheOddsApp.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 27.12.25.
//

import SwiftUI
import GoogleMobileAds

@main
struct BeatTheOddsApp: App {
    init() {
        // Configure Google Mobile Ads SDK
        let mobileAds = MobileAds.shared
        // Register this device for test ads (development only)
        mobileAds.requestConfiguration.testDeviceIdentifiers = [
            "ced985bc4d7c830e9b85b62e51dbed02"
        ]
        // Start the Google Mobile Ads SDK
        mobileAds.start(completionHandler: nil)
        // Optionally, register test device IDs during development to ensure test ads
        // mobileAds.requestConfiguration.testDeviceIdentifiers = ["YOUR-TEST-DEVICE-ID"]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

