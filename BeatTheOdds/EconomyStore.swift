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
    private let saveDebounceInterval: TimeInterval = 5.0
    
    func claimOfflineIncomeIfNeeded() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let ref = db.collection("users").document(uid)

        do {
            let doc = try await ref.getDocument()
            guard let data = doc.data() else { return }

            let cps = (data["coinsPerSecond"] as? Double) ?? Double(data["coinsPerSecond"] as? Int ?? 0)
            guard cps > 0 else { return }

            guard let lastTimestamp = data["lastIncomeClaimAt"] as? Timestamp else { return }

            let elapsed = Date().timeIntervalSince(lastTimestamp.dateValue())
            let cappedElapsed = min(elapsed, 60 * 60 * 12)

            guard cappedElapsed > 1 else { return }

            let earned = floor(cps * cappedElapsed)
            guard earned > 0 else { return }

            try await ref.updateData([
                "coins": FieldValue.increment(earned),
                "netWorth": FieldValue.increment(earned),
                "lastIncomeClaimAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("Offline income claim error:", error)
        }
    }

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
                        "coinsPerSecond": 0.0,
                        "lastIncomeClaimAt": FieldValue.serverTimestamp(),
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], merge: true)
                }

                await MainActor.run {
                    listener = db.collection("users").document(uid)
                        .addSnapshotListener { [weak self] snap, err in
                            guard let self else { return }
                            guard let data = snap?.data() else { return }

                            let m = (data["money"] as? Double) ?? Double(data["money"] as? Int ?? 0)
                            let c = (data["coins"] as? Double) ?? Double(data["coins"] as? Int ?? 0)
                            let cps = (data["coinsPerSecond"] as? Double) ?? 0

                            self.money = m
                            self.coins = c

                           
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
