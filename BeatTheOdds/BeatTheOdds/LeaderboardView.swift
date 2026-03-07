//
//  LeaderboardView.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 02.03.26.
//


import SwiftUI

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friends = FriendsManager()

    @State private var entries: [PublicUserProfile] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack { ProgressView(); Text("Loading…") }
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }

                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, p in
                    HStack(spacing: 8) {
                        // Rank number
                        Text("#\(idx + 1)")
                            .font(.headline)
                            .frame(width: 44, alignment: .leading)

                        // Medal for top 3
                        Group {
                            if idx == 0 { Image(systemName: "medal.fill").foregroundColor(.yellow) }
                            else if idx == 1 { Image(systemName: "medal.fill").foregroundColor(.gray) }
                            else if idx == 2 { Image(systemName: "medal.fill").foregroundColor(.orange) }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.displayName).font(.headline)
                            Text("@\(p.username)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("$\(String(format: "%.2f", p.netWorth))")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            var fetched = try await friends.fetchFriendsLeaderboard()
            fetched.sort { $0.netWorth > $1.netWorth }
            entries = fetched
        } catch {
            errorText = error.localizedDescription
        }
    }
}

