//
//  WalletView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var showingTransactions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Balance Card
                    balanceCard
                    
                    // Stats Grid
                    statsGrid
                    
                    // Recent Transactions
                    recentTransactionsSection
                }
                .padding()
            }
            .navigationTitle("My Wallet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.fetchWallet()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingTransactions) {
                TransactionHistoryView(transactions: viewModel.transactions)
            }
        }
        .task {
            await viewModel.fetchWallet()
        }
    }
    
    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text("Current Balance")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let wallet = viewModel.wallet {
                Text("\(wallet.balance)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("tokens")
                    .font(.title3)
                    .foregroundColor(.secondary)
            } else if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else {
                Text("--")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }
    
    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Total Earned",
                value: "\(viewModel.wallet?.lifetimeEarned ?? 0)",
                icon: "arrow.down.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Total Spent",
                value: "\(viewModel.wallet?.lifetimeSpent ?? 0)",
                icon: "arrow.up.circle.fill",
                color: .red
            )
        }
    }
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                
                Spacer()
                
                Button("See All") {
                    showingTransactions = true
                }
                .font(.caption)
            }
            
            if viewModel.transactions.isEmpty {
                Text("No transactions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.transactions.prefix(3)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct TransactionRow: View {
    let transaction: WalletViewModel.Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transaction.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(transaction.displayAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.amount > 0 ? .green : .red)
        }
        .padding(.vertical, 8)
    }
}

struct TransactionHistoryView: View {
    @Environment(\.dismiss) var dismiss
    let transactions: [WalletViewModel.Transaction]
    
    var body: some View {
        NavigationView {
            List(transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}