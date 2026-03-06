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
        VStack(spacing: 14) {
            Text(isSignUp ? "Create Account" : "Sign In")
                .font(.title2).bold()

            if isSignUp {
                TextField("Username (unique)", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                TextField("Display name", text: $displayName)
                    .autocorrectionDisabled(true)
            }

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled(true)

            SecureField("Password", text: $password)

            if let errorText {
                Text(errorText)
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
                        errorText = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || (isSignUp && username.isEmpty))

            Button(isSignUp ? "Already have an account? Sign in" : "No account? Sign up") {
                isSignUp.toggle()
                errorText = nil
            }
            .font(.footnote)
        }
        .padding()
    }
}
