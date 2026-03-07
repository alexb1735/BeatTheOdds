//
//  UserState.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 05.03.26.
//


import Foundation
import FirebaseFirestore

struct UserState: Codable {
    var username: String?
    var displayName: String?

    @ServerTimestamp var timestamp: Timestamp?

    static let `default` = UserState(
        username: nil,
        displayName: nil,
        timestamp: nil
    )
}
