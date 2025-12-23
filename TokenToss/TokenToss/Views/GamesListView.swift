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
            ZStack {
                // Background gradient
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header with coin toss animation
                        HStack {
                            CoinTossIcon(size: 32)
                            Text("Toss Your Tokens!")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(LinearGradient.tokenGradient)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Last updated & cache status
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                    .foregroundColor(.tokenGold)
                                Text("Updated: \(viewModel.lastUpdated, style: .relative)")
                                    .font(.caption)
                                Spacer()
                            }
                            if let lastApiCall = viewModel.lastApiCall {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.caption)
                                        .foregroundColor(.tokenGold)
                                    Text("API called: \(lastApiCall, style: .relative)")
                                        .font(.caption)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Image(systemName: "externaldrive.fill")
                                        .font(.caption)
                                        .foregroundColor(.tokenGold)
                                    Text("Using cached data")
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.tokenGold.opacity(0.1))
                        )
                        .padding(.horizontal)
                    
                    if viewModel.isLoading && viewModel.games.isEmpty {
                        VStack(spacing: 16) {
                            CoinTossIcon(size: 60)
                            Text("Loading games...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(50)
                    } else if viewModel.games.isEmpty {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.tokenGold.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "sportscourt.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.tokenGold)
                            }
                            Text("No games available")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Check back later for upcoming NFL games")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(50)
                    } else {
                        LazyVStack(spacing: 16) {
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
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Token Toss")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refreshGames()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.tokenGold.opacity(0.2))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.tokenGold)
                                .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                                .animation(
                                    viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                    value: viewModel.isLoading
                                )
                        }
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
            VStack(spacing: 0) {
                // Game time and status header
                HStack {
                    if game.isLive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .tokenPulse()
                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    } else if game.isCompleted {
                        Label("FINAL", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(game.displayTime)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Toss indicator
                    if !game.isCompleted {
                        HStack(spacing: 4) {
                            TokenIcon(size: 16, color: .tokenGold)
                            Text("TOSS")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.tokenGold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.tokenGold.opacity(0.15))
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Away Team
                HStack(spacing: 0) {
                    // Team side indicator
                    Rectangle()
                        .fill(Color.awayTeamPrimary)
                        .frame(width: 4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                // Away badge
                                Text("AWAY")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.awayTeamPrimary)
                                    )
                                
                                Text(game.awayTeam)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            if let score = game.awayScore {
                                Text("\(score)")
                                    .font(.title)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.awayTeamPrimary)
                            }
                        }
                        
                        Spacer()
                        
                        // Odds for away team
                        if !game.isCompleted {
                            VStack(spacing: 4) {
                                Text("ODDS")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(odds?.formattedOdds(for: game.awayTeam, isHome: false) ?? "--")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.awayTeamPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.awayTeamLight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.awayTeamPrimary.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(Color.awayTeamLight.opacity(0.3))
                
                // VS Divider with coin icon
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                    
                    ZStack {
                        Circle()
                            .fill(Color.tokenGold)
                            .frame(width: 32, height: 32)
                        
                        Text("VS")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.tokenGold.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.horizontal)
                
                // Home Team
                HStack(spacing: 0) {
                    // Team side indicator
                    Rectangle()
                        .fill(Color.homeTeamPrimary)
                        .frame(width: 4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                // Home badge
                                Text("HOME")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.homeTeamPrimary)
                                    )
                                
                                Text(game.homeTeam)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            if let score = game.homeScore {
                                Text("\(score)")
                                    .font(.title)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.homeTeamPrimary)
                            }
                        }
                        
                        Spacer()
                        
                        // Odds for home team
                        if !game.isCompleted {
                            VStack(spacing: 4) {
                                Text("ODDS")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(odds?.formattedOdds(for: game.homeTeam, isHome: true) ?? "--")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.homeTeamPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.homeTeamLight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.homeTeamPrimary.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(Color.homeTeamLight.opacity(0.3))
                
                // Tap to toss footer
                if !game.isCompleted {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.caption)
                            Text("Tap to Toss Your Tokens")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.tokenGold)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient.tokenGradient.opacity(0.1)
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.tokenGold.opacity(0.3), Color.tokenBronze.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.tokenGold.opacity(0.15), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
