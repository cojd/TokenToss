//
//  BetHistoryView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI
import Supabase

struct BetHistoryView: View {
    @StateObject private var bettingVM = BettingViewModel()
    @State private var filterStatus: Bet.BetStatus? = nil
    
    private var filteredBets: [Bet] {
        if let filter = filterStatus {
            return bettingVM.bets.filter { $0.betStatus == filter }
        }
        return bettingVM.bets
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "All", isSelected: filterStatus == nil) {
                            filterStatus = nil
                        }
                        FilterChip(title: "Pending", isSelected: filterStatus == .pending) {
                            filterStatus = .pending
                        }
                        FilterChip(title: "Won", isSelected: filterStatus == .won) {
                            filterStatus = .won
                        }
                        FilterChip(title: "Lost", isSelected: filterStatus == .lost) {
                            filterStatus = .lost
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
                
                if bettingVM.isLoadingBets {
                    ProgressView("Loading bets...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredBets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text(filterStatus == nil ? "No bets yet" : "No \(filterStatus!.rawValue) bets")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Your bet history will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredBets) { bet in
                                BetHistoryCard(bet: bet)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Bet History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await bettingVM.loadUserBets()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await bettingVM.loadUserBets()
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color(.systemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

struct BetHistoryCard: View {
    let bet: Bet
    @State private var game: NFLGame?
    
    private var statusIcon: String {
        switch bet.betStatus {
        case .pending:
            return "clock"
        case .won:
            return "checkmark.circle.fill"
        case .lost:
            return "xmark.circle.fill"
        case .cancelled:
            return "minus.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch bet.betStatus {
        case .pending:
            return .orange
        case .won:
            return .green
        case .lost:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                Text(bet.betStatus.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text(bet.placedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Bet details
            VStack(alignment: .leading, spacing: 8) {
                if let game = game {
                    Text("\(game.awayTeam) @ \(game.homeTeam)")
                        .font(.headline)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pick: \(bet.teamBetOn)")
                            .font(.subheadline)
                        Text("Odds: \(bet.formattedOdds)")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Wager: \(bet.wagerAmount) tokens")
                            .font(.subheadline)
                        
                        if bet.betStatus == .won {
                            Text("Won: +\(bet.profit) tokens")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        } else if bet.betStatus == .lost {
                            Text("Lost: \(bet.profit) tokens")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        } else {
                            Text("To Win: \(bet.potentialPayout - bet.wagerAmount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if bet.betStatus == .pending {
                Text("Potential Payout: \(bet.potentialPayout) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .task {
            // Load game details
            do {
                let games: [NFLGame] = try await supabase
                    .from("nfl_games")
                    .select()
                    .eq("id", value: bet.gameId.uuidString)
                    .execute()
                    .value
                
                self.game = games.first
            } catch {
                print("Failed to load game: \(error)")
            }
        }
    }
}