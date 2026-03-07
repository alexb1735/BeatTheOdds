import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Represents a single income upgrade: earn `amount` every `intervalSeconds` seconds.
struct IncomeUpgrade: Codable, Identifiable, Hashable {
    var id: String // stable identifier (e.g., "u1", "u2")
    var title: String
    var amount: Double
    var intervalSeconds: TimeInterval
    var level: Int // purchase level

    init(id: String, title: String, amount: Double, intervalSeconds: TimeInterval, level: Int = 0) {
        self.id = id
        self.title = title
        self.amount = amount
        self.intervalSeconds = intervalSeconds
        self.level = level
    }
}

@MainActor
final class UpgradesStore: ObservableObject {
    @Published private(set) var upgrades: [IncomeUpgrade] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var timers: [String: AnyCancellable] = [:]

    // MARK: - Public API

    /// Call when user signs in; begins listening to Firestore for this user's upgrades.
    func start() {
        stop()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Listen to the user's upgrades document. We store upgrades as a map of id -> fields.
        let ref = db.collection("users").document(uid).collection("game").document("upgrades")
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error { print("Upgrades listener error:", error); return }

            var next: [IncomeUpgrade] = self.defaultUpgrades()
            if let data = snapshot?.data(), let map = data["income"] as? [String: Any] {
                // Merge saved levels into defaults
                next = next.map { base in
                    if let saved = map[base.id] as? [String: Any], let lvl = saved["level"] as? Int {
                        var copy = base
                        copy.level = max(0, lvl)
                        return copy
                    }
                    return base
                }
            }
            self.upgrades = next
            self.restartTimers()
        }
    }

    /// Stop listening and stop passive income timers.
    func stop() {
        listener?.remove()
        listener = nil
        stopTimers()
    }

    /// Purchase/increase the level of an upgrade and persist.
    func incrementLevel(for id: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Update local state immediately for snappy UI
        if let idx = upgrades.firstIndex(where: { $0.id == id }) {
            upgrades[idx].level &+= 1
        }

        // Persist to Firestore at users/{uid}/game/upgrades { income: { id: { level: n } } }
        let ref = db.collection("users").document(uid).collection("game").document("upgrades")
        do {
            try await ref.setData([
                "income": [id: ["level": currentLevel(for: id)]],
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("Upgrades save error:", error)
        }
        restartTimers()
    }

    /// Returns the current level for an upgrade id.
    func currentLevel(for id: String) -> Int {
        upgrades.first(where: { $0.id == id })?.level ?? 0
    }

    // MARK: - Passive income timers

    private func restartTimers() {
        stopTimers()
        for upg in upgrades where upg.level > 0 {
            // total income per tick is amount * level
            let incomePerTick = upg.amount * Double(upg.level)
            let id = upg.id

            let timer = Timer.publish(every: upg.intervalSeconds, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    Task { await self?.grantIncome(amount: incomePerTick) }
                }
            timers[id] = timer
        }
    }

    private func stopTimers() {
        timers.values.forEach { $0.cancel() }
        timers.removeAll()
    }

    /// Hook to deposit income. We write directly to Firestore money field to keep it account-specific.
    private func grantIncome(amount: Double) async {
        guard amount > 0 else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(uid)
        do {
            try await userRef.setData([
                "money": FieldValue.increment(amount),
                "netWorth": FieldValue.increment(amount),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("Passive income write error:", error)
        }
    }

    // MARK: - Defaults

    private func defaultUpgrades() -> [IncomeUpgrade] {
        return [
            IncomeUpgrade(id: "u1", title: "$1 every 5s", amount: 1, intervalSeconds: 5),
            IncomeUpgrade(id: "u2", title: "$5 every 10s", amount: 5, intervalSeconds: 10),
            IncomeUpgrade(id: "u3", title: "$20 every 30s", amount: 20, intervalSeconds: 30)
        ]
    }
}
