//
//  PlaceBetView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI

struct PlaceBetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var bettingVM = BettingViewModel()
    @StateObject private var walletVM = WalletViewModel()
    
    let game: NFLGame
    let odds: Odds
    
    @State private var selectedTeam: String = ""
    @State private var wagerString: String = ""
    @State private var showingConfirmation = false
    
    private var wagerAmount: Int64 {
        Int64(wagerString) ?? 0
    }
    
    private var selectedOdds: Int {
        if selectedTeam == game.homeTeam {
            return odds.homeMoneyline ?? 0
        } else {
            return odds.awayMoneyline ?? 0
        }
    }
    
    private var potentialPayout: Int64 {
        bettingVM.calculatePotentialPayout(wager: wagerAmount, odds: selectedOdds)
    }
    
    private var canPlaceBet: Bool {
        !selectedTeam.isEmpty &&
        wagerAmount > 0 &&
        wagerAmount <= (walletVM.wallet?.balance ?? 0) &&
        !bettingVM.isPlacingBet
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Game info header
                VStack(spacing: 8) {
                    Text(game.displayTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Text(game.awayTeam)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("@")
                            .foregroundColor(.secondary)
                        Text(game.homeTeam)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Team selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Team")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                TeamSelectionRow(
                                    team: game.awayTeam,
                                    odds: odds.formattedOdds(for: game.awayTeam, isHome: false),
                                    isSelected: selectedTeam == game.awayTeam,
                                    onTap: {
                                        withAnimation {
                                            selectedTeam = game.awayTeam
                                        }
                                    }
                                )
                                
                                TeamSelectionRow(
                                    team: game.homeTeam,
                                    odds: odds.formattedOdds(for: game.homeTeam, isHome: true),
                                    isSelected: selectedTeam == game.homeTeam,
                                    onTap: {
                                        withAnimation {
                                            selectedTeam = game.homeTeam
                                        }
                                    }
                                )
                            }
                        }
                        
                        // Wager amount
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Wager Amount")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if let balance = walletVM.wallet?.balance {
                                    Text("Balance: \(balance) tokens")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Text field
                            HStack {
                                Text("🪙")
                                TextField("Enter amount", text: $wagerString)
                                    .keyboardType(.numberPad)
                                    .onChange(of: wagerString) { newValue in
                                        // Remove non-numeric characters
                                        wagerString = newValue.filter { $0.isNumber }
                                    }
                                
                                Text("tokens")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            // Quick bet buttons
                            HStack(spacing: 8) {
                                ForEach([25, 50, 100, 250], id: \.self) { amount in
                                    Button(action: {
                                        wagerString = "\(amount)"
                                    }) {
                                        Text("\(amount)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(wagerString == "\(amount)" ? Color.blue : Color(.systemGray5))
                                            )
                                            .foregroundColor(wagerString == "\(amount)" ? .white : .primary)
                                    }
                                }
                            }
                        }
                        
                        // Bet summary
                        if wagerAmount > 0 && !selectedTeam.isEmpty {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Bet Summary")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Team:")
                                        Spacer()
                                        Text(selectedTeam)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    HStack {
                                        Text("Odds:")
                                        Spacer()
                                        Text(selectedOdds > 0 ? "+\(selectedOdds)" : "\(selectedOdds)")
                                            .fontWeight(.semibold)
                                    }
                                    
                                    HStack {
                                        Text("Wager:")
                                        Spacer()
                                        Text("\(wagerAmount) tokens")
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Text("Potential Payout:")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Text("\(potentialPayout) tokens")
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                    
                                    HStack {
                                        Text("Potential Profit:")
                                            .font(.caption)
                                        Spacer()
                                        Text("+\(potentialPayout - wagerAmount) tokens")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                )
                            }
                        }
                        
                        // Error/Success messages
                        if let error = bettingVM.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        
                        if let success = bettingVM.successMessage {
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.green.opacity(0.1))
                                )
                        }
                    }
                    .padding()
                }
                
                // Place bet button
                VStack(spacing: 8) {
                    Button(action: {
                        if wagerAmount > Int64((walletVM.wallet?.balance ?? 0) / 4) {
                            // Show confirmation for large bets
                            showingConfirmation = true
                        } else {
                            placeBet()
                        }
                    }) {
                        if bettingVM.isPlacingBet {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Place Bet")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canPlaceBet ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!canPlaceBet)
                    
                    Text("Bet responsibly. Virtual tokens only.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Place Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Large Bet", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Place Bet", role: .destructive) {
                    placeBet()
                }
            } message: {
                Text("You're about to bet \(wagerAmount) tokens (over 25% of your balance). Are you sure?")
            }
        }
        .task {
            await walletVM.fetchWallet()
        }
    }
    
    private func placeBet() {
        Task {
            let success = await bettingVM.placeBet(
                gameId: game.id,
                teamBetOn: selectedTeam,
                wagerAmount: wagerAmount,
                oddsAtBet: selectedOdds
            )
            
            if success {
                await walletVM.refreshBalance()
                
                // Dismiss after short delay to show success message
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
}

struct TeamSelectionRow: View {
    let team: String
    let odds: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(team)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(odds)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}