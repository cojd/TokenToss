//
//  GamesListView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI

struct GamesListView: View {
    @StateObject private var viewModel = GamesViewModel()
    @State private var selectedGame: NFLGame?
    @State private var showingBetSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Last updated & cache status
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("Updated: \(viewModel.lastUpdated, style: .relative)")
                                .font(.caption)
                            Spacer()
                        }
                        if let lastApiCall = viewModel.lastApiCall {
                            HStack {
                                Image(systemName: "network")
                                    .font(.caption)
                                Text("API called: \(lastApiCall, style: .relative)")
                                    .font(.caption)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Image(systemName: "network")
                                    .font(.caption)
                                Text("Using cached data")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    if viewModel.isLoading && viewModel.games.isEmpty {
                        ProgressView("Loading games...")
                            .padding(50)
                    } else if viewModel.games.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "sportscourt")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No games available")
                                .font(.title2)
                            Text("Check back later for upcoming NFL games")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(50)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.games) { game in
                                GameCard(
                                    game: game,
                                    odds: viewModel.gameOdds[game.id]
                                ) {
                                    selectedGame = game
                                    showingBetSheet = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("NFL Games")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refreshGames()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(
                                viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                value: viewModel.isLoading
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await viewModel.refreshGames()
            }
        }
        .task {
            await viewModel.loadGames()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .sheet(isPresented: $showingBetSheet) {
            if let game = selectedGame,
               let odds = viewModel.gameOdds[game.id] {
                PlaceBetView(game: game, odds: odds)
            }
        }
    }
}

struct GameCard: View {
    let game: NFLGame
    let odds: Odds?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Game time
                HStack {
                    if game.isLive {
                        Label("LIVE", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    } else if game.isCompleted {
                        Text("FINAL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                    } else {
                        Text(game.displayTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                // Teams and odds
                HStack {
                    // Away team
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.awayTeam)
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let score = game.awayScore {
                            Text("\(score)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    
                    Spacer()
                    
                    // Odds
                    if !game.isCompleted {
                        VStack {
                            Text(odds?.formattedOdds(for: game.awayTeam, isHome: false) ?? "--")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    // Home team
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.homeTeam)
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let score = game.homeScore {
                            Text("\(score)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    
                    Spacer()
                    
                    // Odds
                    if !game.isCompleted {
                        VStack {
                            Text(odds?.formattedOdds(for: game.homeTeam, isHome: true) ?? "--")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}