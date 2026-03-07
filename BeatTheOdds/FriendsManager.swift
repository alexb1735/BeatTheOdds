//
//  FriendsManager.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 01.03.26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

struct PublicUserProfile: Identifiable {
    let id: String      // uid
    let username: String
    let displayName: String
    let netWorth: Double
}

@MainActor
final class FriendsManager: ObservableObject {
    
    private let db = Firestore.firestore()

    func findUser(byUsername username: String) async throws -> PublicUserProfile? {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return nil }

        // 1) Look up uid from usernames registry
        let usernameDoc = try await db.collection("usernames").document(normalized).getDocument()
        guard let data = usernameDoc.data(),
              let uid = data["uid"] as? String else {
            return nil
        }

        // Prevent finding yourself
        if uid == Auth.auth().currentUser?.uid { return nil }

        // 2) Fetch public profile
        let userDoc = try await db.collection("users").document(uid).getDocument()
        guard let u = userDoc.data() else { return nil }

        let displayName = (u["displayName"] as? String) ?? normalized
        let netWorthAny = u["netWorth"]
        let netWorth: Double =
            (netWorthAny as? Double)
            ?? Double(netWorthAny as? Int ?? 0)
        let usernameStored = (u["username"] as? String) ?? normalized

        return PublicUserProfile(id: uid, username: usernameStored, displayName: displayName, netWorth: netWorth)
    }
    
    func sendFriendRequest(to targetUid: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        if myUid == targetUid { return }

        let requestData: [String: Any] = [
            "fromUid": myUid,
            "createdAt": FieldValue.serverTimestamp()
        ]

        // Write into the recipient's incoming requests
        try await db.collection("users")
            .document(targetUid)
            .collection("friendRequests")
            .document(myUid) // use sender uid as doc id to prevent duplicates
            .setData(requestData)
    }

    func fetchUserProfile(uid: String) async throws -> PublicUserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let u = doc.data() else { return nil }

        let username = (u["username"] as? String) ?? ""
        let displayName = (u["displayName"] as? String) ?? username
        let netWorthAny = u["netWorth"]
        let netWorth: Double =
            (netWorthAny as? Double)
            ?? Double(netWorthAny as? Int ?? 0)
        return PublicUserProfile(id: uid, username: username, displayName: displayName, netWorth: netWorth)
    }
    
    func fetchFriendUIDs() async throws -> [String] {
        guard let myUid = Auth.auth().currentUser?.uid else { return [] }

        let snap = try await db.collection("users")
            .document(myUid)
            .collection("friends")
            .getDocuments()

        return snap.documents.map { $0.documentID }
    }

    func fetchFriendsLeaderboard() async throws -> [PublicUserProfile] {
        guard let myUid = Auth.auth().currentUser?.uid else { return [] }

        let friendUIDs = try await fetchFriendUIDs()
        let allUIDs = [myUid] + friendUIDs

        var profiles: [PublicUserProfile] = []
        for uid in allUIDs {
            if let p = try await fetchUserProfile(uid: uid) {
                profiles.append(p)
            }
        }

        profiles.sort { $0.netWorth > $1.netWorth }
        return profiles
    }
    
    struct FriendRequest: Identifiable {
        let id: String       // fromUid
        let fromUid: String
    }

    func fetchIncomingRequests() async throws -> [FriendRequest] {
        guard let myUid = Auth.auth().currentUser?.uid else { return [] }

        let snap = try await db.collection("users")
            .document(myUid)
            .collection("friendRequests")
            .getDocuments()

        return snap.documents.compactMap { doc in
            let fromUid = doc.documentID
            return FriendRequest(id: fromUid, fromUid: fromUid)
        }
    }

    func acceptFriendRequest(from fromUid: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        let now = FieldValue.serverTimestamp()

        let myFriendRef = db.collection("users").document(myUid).collection("friends").document(fromUid)
        let theirFriendRef = db.collection("users").document(fromUid).collection("friends").document(myUid)
        let myReqRef = db.collection("users").document(myUid).collection("friendRequests").document(fromUid)

        // Batch write: add both sides as friends, remove request
        let batch = db.batch()
        batch.setData(["since": now], forDocument: myFriendRef, merge: true)
        batch.setData(["since": now], forDocument: theirFriendRef, merge: true)
        batch.deleteDocument(myReqRef)
        try await batch.commit()
    }
}

