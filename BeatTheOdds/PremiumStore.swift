//
//  PremiumStore.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 09.03.26.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PremiumStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPremiumActive: Bool = false
    @Published var isLoading: Bool = false
    @Published var purchaseError: String?

    private let productIDs: Set<String> = [
        "com.alexb1735.beattheodds.premium.monthly"
    ]

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func start() async {
        await requestProducts()
        await refreshSubscriptionStatus()
    }

    func requestProducts() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let fetchedProducts = try await Product.products(for: Array(productIDs))
            products = fetchedProducts

            print("StoreKit requested IDs:", Array(productIDs))
            print("StoreKit returned products:", fetchedProducts.map(\.id))

            if fetchedProducts.isEmpty {
                purchaseError = "No products were returned by StoreKit."
            }
        } catch {
            print("StoreKit requestProducts error:", error.localizedDescription)
            purchaseError = error.localizedDescription
        }
    }

    func refreshSubscriptionStatus() async {
        var premiumActive = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                premiumActive = true
            }
        }

        isPremiumActive = premiumActive
        UserDefaults.standard.set(premiumActive, forKey: "isPremiumActive")
    }

    func purchaseMonthlyPass() async {
        purchaseError = nil

        guard let product = products.first(where: { $0.id == "com.alexb1735.beattheodds.premium.monthly" }) else {
            purchaseError = "Premium product is not available yet. Please try again later."
            return
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                case .unverified(_, let error):
                    purchaseError = error.localizedDescription
                }

            case .userCancelled:
                break

            case .pending:
                purchaseError = "Purchase is pending approval."

            @unknown default:
                purchaseError = "Unknown purchase result."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                }
            }
        }
    }
}
