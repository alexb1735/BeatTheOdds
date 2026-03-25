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
    @Published var needsProfileSetup: Bool = false

    private let db = Firestore.firestore()

    init() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
            self.firebaseUser = user
            self.user = user

            guard let user else {
                self.needsProfileSetup = false
                return
            }

            Task { @MainActor in
                do {
                    let snapshot = try await self.db.collection("users").document(user.uid).getDocument()
                    let username = (snapshot.data()?["username"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    self.needsProfileSetup = (username == nil || username?.isEmpty == true)
                } catch {
                    self.needsProfileSetup = false
                }
            }
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

        let userRef = db.collection("users").document(user.uid)
        let snapshot = try await userRef.getDocument()
        let data = snapshot.data()

        let existingUsername = (data?["username"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let existingDisplayName = (data?["displayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let appleDisplayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDisplayName = (appleDisplayName?.isEmpty == false ? appleDisplayName! : "Player")

        if let existingUsername, !existingUsername.isEmpty {
            // Existing profile is complete
            needsProfileSetup = false

            // Keep display name updated if it was missing before
            if existingDisplayName == nil || existingDisplayName?.isEmpty == true {
                try await userRef.setData([
                    "displayName": fallbackDisplayName,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            }
        } else {
            // Signed in successfully, but profile is incomplete
            needsProfileSetup = true

            // Create a minimal placeholder doc so later setup can complete it
            try await userRef.setData([
                "displayName": fallbackDisplayName,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
    
    func completeAppleProfile(username: String, displayName: String) async throws {
        authErrorMessage = nil
        isBusy = true
        defer { isBusy = false }

        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthManager",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No signed-in user found."]
            )
        }

        let uid = user.uid
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            throw NSError(
                domain: "AuthManager",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Username cannot be empty."]
            )
        }

        try await db.runTransaction { tx, errorPointer in
            let usernameRef = self.db.collection("usernames").document(normalized)
            let userRef = self.db.collection("users").document(uid)

            do {
                let usernameDoc = try tx.getDocument(usernameRef)

                if usernameDoc.exists {
                    if let existingUID = usernameDoc.data()?["uid"] as? String, existingUID != uid {
                        errorPointer?.pointee = NSError(
                            domain: "AuthManager",
                            code: 409,
                            userInfo: [NSLocalizedDescriptionKey: "Username already taken."]
                        )
                        return nil
                    }
                }

                tx.setData(["uid": uid], forDocument: usernameRef)

                tx.setData([
                    "username": normalized,
                    "displayName": cleanedDisplayName.isEmpty ? normalized : cleanedDisplayName,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: userRef, merge: true)

                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        needsProfileSetup = false
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        self.user = nil
    }
}

