import Foundation
import FirebaseFirestore

struct UserState: Codable {
    var coins: Double
    var money: Double
    var networth: Double

    var username: String?
    var displayName: String?

    @ServerTimestamp var timestamp: Timestamp?

    static let `default` = UserState(
        coins: 100.0,
        money: 0.0,
        networth: 100.0,
        username: nil,
        displayName: nil,
        timestamp: nil
    )
}