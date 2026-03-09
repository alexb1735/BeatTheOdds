//
//  LeaderboardView.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 02.03.26.
//


import SwiftUI
import FirebaseAuth

enum LeaderboardMode: String, CaseIterable {
    case friends = "Friends"
    case global = "Global"
}

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friends = FriendsManager()

    @State private var entries: [PublicUserProfile] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var myUID: String = ""
    @State private var mode: LeaderboardMode = .friends

    var body: some View {
        NavigationStack {
            ScrollViewReader{ proxy in
                List {
                    
                    Picker("Leaderboard", selection: $mode) {
                        ForEach(LeaderboardMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                    .onChange(of: mode) { _, _ in
                        Task { await load() }
                    }
                    
                    if isLoading {
                        HStack { ProgressView(); Text("Loading…") }
                    }
                    
                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }
                    
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, p in
                        let isMe = p.id == myUID
                        let titleText = p.title ?? ""
                        let hasTitle = !titleText.isEmpty
                        
                        HStack(spacing: 8) {
                            Text("#\(idx + 1)")
                                .font(.headline)
                                .frame(width: 36, alignment: .leading)
                            Group {
                                if idx == 0 {
                                    Image(systemName: "crown.fill").foregroundColor(.yellow)
                                } else if idx == 1 {
                                    Image(systemName: "medal.fill").foregroundColor(.gray)
                                } else if idx == 2 {
                                    Image(systemName: "medal.fill").foregroundColor(.orange)
                                }
                            }
                            .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(p.displayName)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    
                                    if isMe {
                                        Text("YOU")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.25))
                                            .cornerRadius(6)
                                    }
                                }
                                
                                if hasTitle {
                                    Text(titleText)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(titleColor(titleText))
                                        .lineLimit(1)
                                }
                                
                                Text("@\(p.username)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .truncationMode(.tail)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                            
                            Text("$\(formatNumber(p.netWorth))")
                                .font(.headline)
                                .monospacedDigit()
                                .frame(width: 90, alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(isMe ? Color.blue.opacity(0.12) : Color.clear)
                        .cornerRadius(10)
                        .id(p.id)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        
                    }
                }
                .task {
                    await load()

                    if let myEntry = entries.first(where: { $0.id == myUID }) {
                        withAnimation {
                            proxy.scrollTo(myEntry.id, anchor: .center)
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorText = nil
        myUID = Auth.auth().currentUser?.uid ?? ""
        defer { isLoading = false }

        do {
            let fetched: [PublicUserProfile]

            switch mode {
            case .friends:
                fetched = try await friends.fetchFriendsLeaderboard()
            case .global:
                fetched = try await friends.fetchGlobalLeaderboard()
            }

            entries = fetched.sorted { $0.netWorth > $1.netWorth }
        } catch {
            errorText = error.localizedDescription
        }
    }
    private func titleColor(_ title: String) -> Color {
        switch title {
        case "Tycoon": return .purple
        case "Millionaire": return .yellow
        case "High Roller": return .orange
        case "Investor": return .blue
        default: return .secondary
        }
    }
}

