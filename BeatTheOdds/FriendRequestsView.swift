import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friends = FriendsManager()

    @State private var requests: [FriendsManager.FriendRequest] = []
    @State private var profilesByUid: [String: PublicUserProfile] = [:]
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack { ProgressView(); Text("Loading…") }
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }

                if requests.isEmpty && !isLoading {
                    Text("No friend requests yet.")
                        .foregroundStyle(.secondary)
                }

                ForEach(requests) { req in
                    let profile = profilesByUid[req.fromUid]

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.displayName ?? "Unknown")
                                .font(.headline)
                            Text("@\(profile?.username ?? req.fromUid)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Accept") {
                            Task { await accept(fromUid: req.fromUid) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Friend Requests")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await load()
            }
            .refreshable {
                await load()
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let reqs = try await friends.fetchIncomingRequests()
            requests = reqs

            // Fetch profiles for nicer display
            var dict: [String: PublicUserProfile] = [:]
            for r in reqs {
                if let p = try await friends.fetchUserProfile(uid: r.fromUid) {
                    dict[r.fromUid] = p
                }
            }
            profilesByUid = dict
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func accept(fromUid: String) async {
        errorText = nil
        do {
            try await friends.acceptFriendRequest(from: fromUid)
            // Remove locally for instant UI update
            requests.removeAll { $0.fromUid == fromUid }
            profilesByUid[fromUid] = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}