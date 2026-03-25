//
//  AuthView.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 01.03.26.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var errorText: String?
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            // Background matching the main game UI
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .blur(radius: 6)

            VStack(spacing: 18) {
                // Welcome headline
                Text("Welcome to BeatTheOdds!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)

                // Card container for auth fields
                VStack(spacing: 14) {
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)

                    if isSignUp {
                        TextField("Username (unique)", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)

                        TextField("Display name", text: $displayName)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let msg = auth.authErrorMessage ?? errorText {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button(isSignUp ? "Sign Up" : "Sign In") {
                        Task {
                            errorText = nil
                            do {
                                if isSignUp {
                                    try await auth.signUp(
                                        email: email,
                                        password: password,
                                        username: username,
                                        displayName: displayName.isEmpty ? username : displayName
                                    )
                                } else {
                                    try await auth.signIn(email: email, password: password)
                                }
                            } catch {
                                print("SIGNUP ERROR:", error)
                                errorText = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(auth.isBusy || email.isEmpty || password.isEmpty || (isSignUp && username.isEmpty))

                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(10)
                    
                    Button(isSignUp ? "Already have an account? Sign in" : "No account? Sign up") {
                        isSignUp.toggle()
                        errorText = nil
                        auth.authErrorMessage = nil
                    }
                    .font(.footnote)
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
                .frame(maxWidth: 360)
            }
            .padding()
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorText = error.localizedDescription

        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorText = "Apple sign-in failed."
                return
            }

            guard let nonce = currentNonce else {
                errorText = "Invalid sign-in state."
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken else {
                errorText = "Unable to fetch identity token."
                return
            }

            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorText = "Unable to decode identity token."
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            Task {
                do {
                    try await auth.signInWithApple(credential: credential)
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}


struct CompleteProfileView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var username = ""
    @State private var displayName = ""
    @State private var errorText: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .blur(radius: 6)

            VStack(spacing: 18) {
                Text("Complete Your Profile")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    Text("Choose a username so friends can find you.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("Username (unique)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)

                    TextField("Display name", text: $displayName)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button("Save Profile") {
                        Task {
                            do {
                                try await auth.completeAppleProfile(
                                    username: username,
                                    displayName: displayName.isEmpty ? username : displayName
                                )
                            } catch {
                                errorText = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(auth.isBusy || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
                .frame(maxWidth: 360)
            }
            .padding()
        }
    }
}
