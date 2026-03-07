//
//  UserStateStore.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 05.03.26.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

struct AppUserState: Codable {
    var coins: Double
    var money: Double
    var netWorth: Double
    var username: String?
    var displayName: String?
    static let `default` = AppUserState(coins: 0, money: 0, netWorth: 0, username: nil, displayName: nil)
}

@MainActor
final class UserStateStore: ObservableObject {

    @Published var state: AppUserState = .default

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        listener = db.collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard let snapshot else { return }

                // ✅ If snapshot.data(as:) works for you right now, keep it:
                if let userState = try? snapshot.data(as: AppUserState.self) {
                    self.state = userState
                } else if let data = snapshot.data() {
                    let coins = data["coins"] as? Double ?? 0
                    let money = data["money"] as? Double ?? 0
                    let netWorth = data["netWorth"] as? Double ?? (coins + money)
                    let username = data["username"] as? String
                    let displayName = data["displayName"] as? String
                    self.state = AppUserState(coins: coins, money: money, netWorth: netWorth, username: username, displayName: displayName)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Write helpers (THIS is what you were missing)

    func updateCoins(_ newCoins: Double) {
        state.coins = newCoins
        write(fields: ["coins": newCoins])
        writeNetWorth()
    }

    func updateMoney(_ newMoney: Double) {
        state.money = newMoney
        write(fields: ["money": newMoney])
        writeNetWorth()
    }

    func updateDisplayName(_ name: String) {
        state.displayName = name
        write(fields: ["displayName": name])
    }

    func updateUsername(_ username: String) {
        state.username = username
        write(fields: ["username": username])
    }
    
    private func writeNetWorth() {
        let net = state.coins + state.money
        state.netWorth = net
        write(fields: ["netWorth": net])
    }

    // MARK: - Private

    private func write(fields: [String: Any]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var payload = fields
        payload["updatedAt"] = FieldValue.serverTimestamp()

        db.collection("users")
            .document(uid)
            .setData(payload, merge: true)
    }

  
}

