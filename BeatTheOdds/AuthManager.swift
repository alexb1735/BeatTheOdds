//
//  AuthManager.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 01.03.26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthManager: ObservableObject {
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var firebaseUser: User?

    @Published var user: User? = nil
    @Published var authErrorMessage: String?
    @Published var isBusy: Bool = false

    private let db = Firestore.firestore()

    init() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
            self.firebaseUser = user
            self.user = user
        }
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        
        authErrorMessage = nil
        isBusy = true
        defer { isBusy = false }

        // 1) Create Auth user (temporary until we successfully claim username)
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let createdUser = result.user

        let uid = createdUser.uid
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            // 2) Claim username + create user profile atomically
            let _ = try await db.runTransaction { tx, errorPointer in
                let usernameRef = self.db.collection("usernames").document(normalized)
                let userRef = self.db.collection("users").document(uid)

                do {
                    let usernameDoc = try tx.getDocument(usernameRef)
                    if usernameDoc.exists {
                        errorPointer?.pointee = NSError(
                            domain: "AuthManager",
                            code: 409,
                            userInfo: [NSLocalizedDescriptionKey: "Username already taken."]
                        )
                        return nil
                    }

                    tx.setData(["uid": uid], forDocument: usernameRef)

                    tx.setData([
                        "username": normalized,
                        "displayName": displayName,

                        // economy fields (NEW)
                        "money": 0,
                        "coins": 0,
                        "netWorth": 0,

                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: userRef, merge: true)

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }

            // 3) ✅ Only now consider signup successful
            self.user = createdUser

        } catch {
            // 4) ❌ Transaction failed: delete the Auth user so signup truly fails
            do { try await createdUser.delete() } catch { /* ignore */ }
            try? Auth.auth().signOut()
            self.user = nil
            self.authErrorMessage = error.localizedDescription
            throw error
        }
    }
    func signIn(email: String, password: String) async throws {
        authErrorMessage = nil
        isBusy = true
        defer { isBusy = false }
        
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.user = result.user
    }

    func signInWithApple(credential: AuthCredential) async throws {
        authErrorMessage = nil
        isBusy = true
        defer { isBusy = false }

        let result = try await Auth.auth().signIn(with: credential)
        let user = result.user

        self.user = user

        let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = displayName?.isEmpty == false ? displayName! : "Player"

        let data: [String: Any] = [
            "displayName": fallbackName,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .setData(data, merge: true)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        self.user = nil
    }
}

