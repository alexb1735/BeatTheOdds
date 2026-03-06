import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class EconomyStore: ObservableObject {
    @Published private(set) var money: Double = 0
    @Published private(set) var coins: Double = 0

    var netWorth: Double { money + coins }

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func start() {
        stop()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err { print("Economy listener error:", err); return }
            let data = snap?.data() ?? [:]

            let m = (data["money"] as? Double) ?? Double((data["money"] as? Int) ?? 0)
            let c = (data["coins"] as? Double) ?? Double((data["coins"] as? Int) ?? 0)

            // Only update if changed to avoid UI loops
            if self.money != m { self.money = m }
            if self.coins != c { self.coins = c }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Call whenever the game updates money/coins
    func set(money newMoney: Double, coins newCoins: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Update locally immediately
        money = newMoney
        coins = newCoins

        do {
            try await db.collection("users").document(uid).updateData([
                "money": newMoney,
                "coins": newCoins,
                "netWorth": newMoney + newCoins, // keep leaderboard fast
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("Economy update error:", error)
        }
    }

    // Convenience helpers
    func addMoney(_ delta: Double) async { await set(money: money + delta, coins: coins) }
    func addCoins(_ delta: Double) async { await set(money: money, coins: coins + delta) }
}