import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class EconomyStore: ObservableObject {
    @Published var money: Double = 0
    @Published var coins: Double = 0

    var netWorth: Double { money + coins }

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var pendingSaveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5

    func start() {
        stop()

        guard let uid = Auth.auth().currentUser?.uid else { return }

        let ref = db.collection("users").document(uid)

        Task { [weak self] in
            do {
                let doc = try await ref.getDocument()

                if !doc.exists {
                    try await ref.setData([
                        "money": 0.0,
                        "coins": 100.0,
                        "netWorth": 100.0,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], merge: true)
                }

                await MainActor.run {
                    self?.listener = ref.addSnapshotListener { [weak self] snap, err in
                        guard let self else { return }
                        if let data = snap?.data() {
                            let m = (data["money"] as? Double) ?? Double(data["money"] as? Int ?? 0)
                            let c = (data["coins"] as? Double) ?? Double(data["coins"] as? Int ?? 0)

                            self.money = m
                            self.coins = c
                        }
                    }
                }
            } catch {
                print("User initialization error:", error)
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
    }

    private func scheduleSave() {
        pendingSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { await self.save() }
        }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval, execute: work)
    }

    func save() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(uid).setData([
                "money": money,
                "coins": coins,
                "netWorth": money + coins,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("Economy save error:", error)
        }
    }

    func addMoney(_ amount: Double) {
        money += amount
        scheduleSave()
    }

    func addCoins(_ amount: Double) {
        coins += amount
        scheduleSave()
    }
}
