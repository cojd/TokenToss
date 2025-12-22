//
//  Bet.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import Foundation

struct Bet: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let gameId: UUID
    let betType: String
    let teamBetOn: String
    let wagerAmount: Int64
    let oddsAtBet: Int
    let potentialPayout: Int64
    let betStatus: BetStatus
    let payoutAmount: Int64
    let placedAt: Date
    let settledAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case gameId = "game_id"
        case betType = "bet_type"
        case teamBetOn = "team_bet_on"
        case wagerAmount = "wager_amount"
        case oddsAtBet = "odds_at_bet"
        case potentialPayout = "potential_payout"
        case betStatus = "bet_status"
        case payoutAmount = "payout_amount"
        case placedAt = "placed_at"
        case settledAt = "settled_at"
    }
    
    enum BetStatus: String, Codable {
        case pending
        case won
        case lost
        case cancelled
    }
    
    var formattedOdds: String {
        return oddsAtBet > 0 ? "+\(oddsAtBet)" : "\(oddsAtBet)"
    }
    
    var profit: Int64 {
        switch betStatus {
        case .won:
            return potentialPayout - wagerAmount
        case .lost:
            return -wagerAmount
        default:
            return 0
        }
    }
}

// Place bet response
struct PlaceBetResponse: Codable {
    let success: Bool
    let message: String
    let betId: UUID?
    let newBalance: Int64?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case betId = "bet_id"
        case newBalance = "new_balance"
    }
}