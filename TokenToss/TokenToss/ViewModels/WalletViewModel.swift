//
//  WalletViewModel.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI
import Supabase
import Combine

@MainActor
class WalletViewModel: ObservableObject {
    @Published var wallet: Wallet?
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    struct Transaction: Identifiable, Codable {
        let id: UUID
        let walletId: UUID
        let transactionType: String
        let amount: Int64
        let balanceBefore: Int64
        let balanceAfter: Int64
        let betId: UUID?
        let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case walletId = "wallet_id"
            case transactionType = "transaction_type"
            case amount
            case balanceBefore = "balance_before"
            case balanceAfter = "balance_after"
            case betId = "bet_id"
            case createdAt = "created_at"
        }
        
        var displayAmount: String {
            let prefix = amount > 0 ? "+" : ""
            return "\(prefix)\(amount) tokens"
        }
        
        var displayType: String {
            switch transactionType {
            case "initial_grant":
                return "Welcome Bonus"
            case "bet_placed":
                return "Bet Placed"
            case "bet_won":
                return "Bet Won!"
            case "bet_refunded":
                return "Bet Refunded"
            default:
                return transactionType
            }
        }
    }
    
    func fetchWallet() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            let wallet: Wallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.wallet = wallet
            await fetchTransactions()
        } catch {
            errorMessage = "Failed to fetch wallet: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchTransactions() async {
        guard let walletId = wallet?.id else { return }
        
        do {
            let transactions: [Transaction] = try await supabase
                .from("transactions")
                .select()
                .eq("wallet_id", value: walletId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            self.transactions = transactions
        } catch {
            print("Failed to fetch transactions: \(error)")
        }
    }
    
    func refreshBalance() async {
        guard let currentWallet = wallet else { return }
        
        do {
            let updatedWallet: Wallet = try await supabase
                .from("wallets")
                .select()
                .eq("id", value: currentWallet.id.uuidString)
                .single()
                .execute()
                .value
            
            withAnimation {
                self.wallet = updatedWallet
            }
        } catch {
            print("Failed to refresh balance: \(error)")
        }
    }
}