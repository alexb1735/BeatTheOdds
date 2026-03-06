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
                    HStack {
                        Text("#\(idx + 1)")
                            .font(.headline)
                            .frame(width: 44, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.displayName).font(.headline)
                            Text("@\(p.username)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("$\(p.netWorth)")
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
            entries = try await friends.fetchFriendsLeaderboard()
        } catch {
            errorText = error.localizedDescription
        }
    }
}