import SwiftUI

struct AddFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var username: String = ""
    @StateObject private var friends = FriendsManager()
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @State private var result: PublicUserProfile? = nil
    @State private var errorText: String? = nil
    @State private var sentRequests: Set<String> = []
    
    var body: some View {
        ZStack {
            // Background matching ContentView
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .blur(radius: 6)

            // Foreground content
            NavigationStack {
                Form {
                    Section(header: Text("Add a Friend")) {
                        TextField("Username", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await search() }
                            }
                    }

                    if isSearching {
                        Section {
                            HStack {
                                ProgressView()
                                Text("Searching...")
                            }
                        }
                    }

                    if let err = searchError {
                        Section(header: Text("Error")) {
                            Text(err).foregroundStyle(.red)
                        }
                    }

                    if let user = result {
                        Section(header: Text("Result")) {
                            FriendSearchResultView(user: user, sentRequests: $sentRequests) { targetUid in
                                do {
                                    try await friends.sendFriendRequest(to: targetUid)
                                    await MainActor.run { sentRequests.insert(targetUid) }
                                } catch {
                                    await MainActor.run { searchError = error.localizedDescription }
                                }
                            }

                            if let errorText {
                                Text(errorText).foregroundStyle(.red).font(.footnote)
                            }
                        }
                    }                }
                .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .blur(radius: 6)
                )
                .navigationTitle("Add Friend")
              
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        
                    }
                }
            }
        }
    }
    
    // Optional: future async search hook
    private func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        await MainActor.run {
            isSearching = true
            searchError = nil
            result = nil
        }
        do {
            let found = try await friends.findUser(byUsername: q)
            await MainActor.run {
                self.result = found
                
                if let found { self.username = found.username } else { self.username = "" }
                self.isSearching = false
                if found == nil { self.searchError = "No user found for \"\(q)\"." }
            }
        } catch {
            await MainActor.run {
                self.isSearching = false
                self.searchError = error.localizedDescription
                self.result = nil
                
            }
        }
    }
}

#Preview {
    AddFriendsView()
}

