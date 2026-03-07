//
//  AuthView.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 01.03.26.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var errorText: String?

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
}
