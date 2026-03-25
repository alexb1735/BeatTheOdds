//
//  StatsView.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 25.03.26.
//

import Foundation
import SwiftUI

struct StatsView: View {
    let stats: FriendStatsProfile

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.green.opacity(0.5), Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.green)
                    Text(stats.displayName)
                        .font(.title3)
                        .bold()
                }

                Text("@\(stats.username)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if !stats.title.isEmpty {
                    Text(stats.title)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 8) {
                    statRow("crown", .yellow, "Highest net worth: $\(formatNumber(stats.highestNetworth))")
                    statRow("dollarsign.circle", .blue, "Total money made: $\(formatNumber(stats.totalMoneyMade))")
                    statRow("clock", .blue, "Total time played: \(formatPlayTime(stats.totalTimePlayed))")
                    statRow("flame", .red, "Longest win streak: \(stats.longestWinStreak)")
                    statRow("snow", .cyan, "Longest loss streak: \(stats.longestLossStreak)")
                    statRow("arrow.up.right", .green, "Largest gain: $\(formatNumber(stats.largestSingleGain))")
                    statRow("chart.bar", .orange, "Games played: \(stats.gamesPlayed)")
                    statRow("checkmark.seal", .green, "Games won: \(stats.gamesWon)")

                    let winRate = stats.gamesPlayed > 0
                        ? String(format: "%.1f", Double(stats.gamesWon) * 100.0 / Double(stats.gamesPlayed))
                        : "0.0"

                    statRow("percent", .orange, "Win rate: \(winRate)%")
                    statRow("banknote", .blue, "Net worth: $\(formatNumber(stats.netWorth))")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            .padding()
        }
    }

    private func statRow(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.subheadline)
        }
    }
    private func formatPlayTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
