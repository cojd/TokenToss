//
//  RivalriesView.swift
//  TokenToss
//
//  Head-to-head rivalry tracking for friend-first competition
//

import SwiftUI

struct RivalriesView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    @State private var rivalries: [RivalrySummary] = []
    @State private var isLoading = true
    @State private var selectedRival: RivalrySummary?

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rivalries")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if let group = groupViewModel.currentGroup {
                            Text(group.name)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(TokenTossTheme.gold)
                }
                .padding()
                .background(Color.black.opacity(0.3))

                // Rivalries List
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: TokenTossTheme.gold))
                    Spacer()
                } else if rivalries.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No rivalries yet")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Place bets on the same games as your friends to start tracking rivalries")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(rivalries) { rivalry in
                                RivalryCard(rivalry: rivalry)
                                    .onTapGesture {
                                        selectedRival = rivalry
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .task {
            await loadRivalries()
        }
        .refreshable {
            await loadRivalries()
        }
        .sheet(item: $selectedRival) { rivalry in
            RivalryDetailView(
                groupViewModel: groupViewModel,
                rivalry: rivalry
            )
        }
    }

    private func loadRivalries() async {
        isLoading = true
        rivalries = await groupViewModel.getAllRivalries()
        isLoading = false
    }
}

// MARK: - Rivalry Card

struct RivalryCard: View {
    let rivalry: RivalrySummary

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rivalry.rivalUsername)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(rivalry.matchups) matchups")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Win/Loss indicator
                WinLossBadge(isWinning: rivalry.isWinning)
            }

            // Record
            HStack(spacing: 20) {
                StatBox(
                    label: "W",
                    value: "\(rivalry.wins)",
                    color: .green
                )

                StatBox(
                    label: "L",
                    value: "\(rivalry.losses)",
                    color: .red
                )

                StatBox(
                    label: "T",
                    value: "\(rivalry.ties)",
                    color: .gray
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Win Rate")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("\(Int(rivalry.winRate))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(rivalry.isWinning ? .green : .red)
                }
            }

            // Profit differential
            HStack {
                Text("Token Differential")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(rivalry.profitDiff > 0 ? "+" : "")\(rivalry.profitDiff)")
                    .font(.headline)
                    .foregroundColor(rivalry.profitDiff > 0 ? .green : rivalry.profitDiff < 0 ? .red : .gray)
            }

            // Last matchup
            if let lastMatchup = rivalry.lastMatchup {
                Text("Last matchup: \(lastMatchup.formatted(.dateTime.month().day()))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color.gray.opacity(0.2),
                    Color.gray.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(rivalry.isWinning ? Color.green.opacity(0.5) : Color.red.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Views

struct WinLossBadge: View {
    let isWinning: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isWinning ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            Text(isWinning ? "Winning" : "Losing")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundColor(isWinning ? .green : .red)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isWinning ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        .cornerRadius(20)
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(width: 50)
    }
}

// MARK: - Rivalry Detail View

struct RivalryDetailView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    let rivalry: RivalrySummary
    @Environment(\.dismiss) private var dismiss

    @State private var rivalryStats: RivalryStats?
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("vs \(rivalry.rivalUsername)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text(rivalry.record)
                                .font(.title3)
                                .foregroundColor(TokenTossTheme.gold)
                        }
                        .padding(.top)

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: TokenTossTheme.gold))
                        } else if let stats = rivalryStats {
                            // Detailed stats
                            VStack(spacing: 16) {
                                StatsRow(label: "Total Matchups", value: "\(stats.stats.totalMatchups)")
                                StatsRow(label: "You Won", value: "\(stats.stats.user1Wins)", color: .green)
                                StatsRow(label: "They Won", value: "\(stats.stats.user2Wins)", color: .red)
                                StatsRow(label: "Both Won", value: "\(stats.stats.bothWon)", color: .blue)
                                StatsRow(label: "Both Lost", value: "\(stats.stats.bothLost)", color: .orange)
                                StatsRow(label: "Opposite Picks", value: "\(stats.stats.oppositePicksCount)")
                                StatsRow(label: "Your Total Profit", value: "\(stats.stats.user1TotalProfit)", color: .green)
                                StatsRow(label: "Their Total Profit", value: "\(stats.stats.user2TotalProfit)", color: .red)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)

                            // Recent matchups
                            if !stats.recentMatchups.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Recent Matchups")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    ForEach(stats.recentMatchups) { matchup in
                                        MatchupRow(matchup: matchup, stats: stats)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(TokenTossTheme.gold)
                }
            }
        }
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        rivalryStats = await groupViewModel.getRivalryStats(withUser: rivalry.rivalId)
        isLoading = false
    }
}

struct StatsRow: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct MatchupRow: View {
    let matchup: RivalryMatchup
    let stats: RivalryStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(matchup.awayTeam) @ \(matchup.homeTeam)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            HStack {
                Text("You: \(matchup.user1Pick)")
                    .font(.caption)
                    .foregroundColor(matchup.user1Result == "won" ? .green : .red)

                Spacer()

                Text("Them: \(matchup.user2Pick)")
                    .font(.caption)
                    .foregroundColor(matchup.user2Result == "won" ? .green : .red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}
