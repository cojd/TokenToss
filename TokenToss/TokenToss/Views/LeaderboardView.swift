//
//  LeaderboardView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI
import Combine
import Supabase

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Loading leaderboard...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Top 3 podium
                            if viewModel.topThree.count >= 3 {
                                PodiumView(topThree: viewModel.topThree)
                                    .padding()
                            }
                            
                            // Full leaderboard
                            VStack(spacing: 2) {
                                ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.userId) { index, entry in
                                    LeaderboardRow(
                                        entry: entry,
                                        rank: index + 1,
                                        isCurrentUser: entry.userId == viewModel.currentUserId
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadLeaderboard()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await viewModel.loadLeaderboard()
        }
    }
}

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var currentUserId: UUID?
    
    struct LeaderboardEntry: Identifiable {
        let userId: UUID
        let username: String
        let balance: Int64
        let totalBets: Int
        let wins: Int
        let losses: Int
        
        var id: UUID { userId }
        
        var winRate: String {
            guard totalBets > 0 else { return "0%" }
            let rate = Double(wins) / Double(totalBets) * 100
            return String(format: "%.0f%%", rate)
        }
    }
    
    var topThree: [LeaderboardEntry] {
        Array(leaderboard.prefix(3))
    }
    
    func loadLeaderboard() async {
        isLoading = true
        
        do {
            // Get current user
            currentUserId = try await supabase.auth.session.user.id
            
            // Query for leaderboard data
            let query = """
                SELECT 
                    w.user_id,
                    p.username,
                    w.balance,
                    COUNT(b.id) as total_bets,
                    COUNT(CASE WHEN b.bet_status = 'won' THEN 1 END) as wins,
                    COUNT(CASE WHEN b.bet_status = 'lost' THEN 1 END) as losses
                FROM wallets w
                JOIN profiles p ON w.user_id = p.id
                LEFT JOIN bets b ON w.user_id = b.user_id
                GROUP BY w.user_id, p.username, w.balance
                ORDER BY w.balance DESC
                LIMIT 50
            """
            
            // #region agent log
            let logData1: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "F",
                "location": "LeaderboardView.swift:114",
                "message": "Before RPC call",
                "data": ["rpcName": "query", "queryLength": query.count],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData1 = try? JSONSerialization.data(withJSONObject: logData1),
               let url1 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var request1 = URLRequest(url: url1)
                request1.httpMethod = "POST"
                request1.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request1.httpBody = jsonData1
                _ = try? await URLSession.shared.data(for: request1)
            }
            // #endregion
            
            let result = try await supabase
                .rpc("query", params: ["sql": query])
                .execute()
            
            // #region agent log
            let logData2: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "F",
                "location": "LeaderboardView.swift:120",
                "message": "After RPC call",
                "data": ["hasData": true, "dataSize": result.data.count],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData2 = try? JSONSerialization.data(withJSONObject: logData2),
               let url2 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var request2 = URLRequest(url: url2)
                request2.httpMethod = "POST"
                request2.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request2.httpBody = jsonData2
                _ = try? await URLSession.shared.data(for: request2)
            }
            // #endregion
            
            // Parse the results
            let data = result.data
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                leaderboard = jsonArray.compactMap { dict in
                    guard let userIdString = dict["user_id"] as? String,
                          let userId = UUID(uuidString: userIdString),
                          let username = dict["username"] as? String,
                          let balance = dict["balance"] as? Int64,
                          let totalBets = dict["total_bets"] as? Int,
                          let wins = dict["wins"] as? Int,
                          let losses = dict["losses"] as? Int else {
                        return nil
                    }
                    
                    return LeaderboardEntry(
                        userId: userId,
                        username: username,
                        balance: balance,
                        totalBets: totalBets,
                        wins: wins,
                        losses: losses
                    )
                }
            }
        } catch {
            print("Failed to load leaderboard: \(error)")
        }
        
        isLoading = false
    }
}

struct PodiumView: View {
    let topThree: [LeaderboardViewModel.LeaderboardEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Second place
            if topThree.count > 1 {
                PodiumSpot(entry: topThree[1], rank: 2, height: 80)
            }
            
            // First place
            if topThree.count > 0 {
                PodiumSpot(entry: topThree[0], rank: 1, height: 100)
            }
            
            // Third place
            if topThree.count > 2 {
                PodiumSpot(entry: topThree[2], rank: 3, height: 60)
            }
        }
    }
}

struct PodiumSpot: View {
    let entry: LeaderboardViewModel.LeaderboardEntry
    let rank: Int
    let height: CGFloat
    
    private var medal: String {
        switch rank {
        case 1:
            return "🥇"
        case 2:
            return "🥈"
        case 3:
            return "🥉"
        default:
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(medal)
                .font(.title)
            
            VStack(spacing: 4) {
                Text(entry.username)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(entry.balance)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: rank == 1 ? [.yellow, .orange] : [.gray, .gray.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: height)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 8
                    )
                )
        }
        .frame(maxWidth: .infinity)
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardViewModel.LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.headline)
                .frame(width: 40, alignment: .leading)
                .foregroundColor(rank <= 3 ? .orange : .primary)
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.subheadline)
                    .fontWeight(isCurrentUser ? .bold : .regular)
                
                Text("\(entry.wins)W - \(entry.losses)L • \(entry.winRate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.balance)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}