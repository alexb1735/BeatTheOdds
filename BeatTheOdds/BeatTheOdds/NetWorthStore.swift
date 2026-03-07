//
//  NetWorthStore.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 02.03.26.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class NetWorthStore: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()
    
    @Published private(set) var netWorth: Int = 0

    init() {}

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func start() {
        stop()

        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Realtime sync from Firestore -> app
        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err { print("NetWorth listener error:", err); return }
            let value = (snap?.data()?["netWorth"] as? Int) ?? 0
            if self.netWorth != value {
                self.netWorth = value
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Call this whenever the player earns/spends money.
    func setNetWorth(_ newValue: Int) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if newValue == netWorth { return }

        // Update locally immediately (snappy UI)
        netWorth = newValue

        do {
            try await db.collection("users").document(uid).updateData([
                "netWorth": newValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("NetWorth update error:", error)
        }
    }
}

