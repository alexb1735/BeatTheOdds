//
//  FriendSearchResultView.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 02.03.26.
//

import SwiftUI

struct FriendSearchResultView: View {
    let user: PublicUserProfile
    @Binding var sentRequests: Set<String>

    let sendRequest: (String) async -> Void

    var alreadySent: Bool {
        sentRequests.contains(user.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(user.displayName).font(.headline)
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Net worth: $\(String(format: "%.2f", user.netWorth))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Button(alreadySent ? "Request Sent" : "Send Friend Request") {
                Task { await sendRequest(user.id) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(alreadySent)

            if alreadySent {
                Text("Friend request sent.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }
}
