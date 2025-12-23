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
    let groupId: UUID?  // New: group context for bet
    let betType: String
    let teamBetOn: String
    let wagerAmount: Int64
    let oddsAtBet: Int
    let potentialPayout: Int64
    let betStatus: BetStatus
    let payoutAmount: Int64
    let placedAt: Date
    let settledAt: Date?
    let betDetail: BetDetail?  // New: structured bet data

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case gameId = "game_id"
        case groupId = "group_id"
        case betType = "bet_type"
        case teamBetOn = "team_bet_on"
        case wagerAmount = "wager_amount"
        case oddsAtBet = "odds_at_bet"
        case potentialPayout = "potential_payout"
        case betStatus = "bet_status"
        case payoutAmount = "payout_amount"
        case placedAt = "placed_at"
        case settledAt = "settled_at"
        case betDetail = "bet_detail"
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

    // Human-readable bet description
    var betDescription: String {
        if let detail = betDetail {
            switch detail.type {
            case "spread":
                let line = detail.line ?? 0
                let team = detail.team ?? teamBetOn
                return "\(team.capitalized) \(line > 0 ? "+" : "")\(line)"
            case "total":
                let selection = detail.selection ?? teamBetOn
                let line = detail.line ?? 0
                return "\(selection.capitalized) \(line)"
            default:
                return "\(teamBetOn) (\(betType))"
            }
        }
        return "\(teamBetOn) (\(betType))"
    }
}

// MARK: - Bet Detail (for spread and totals)

struct BetDetail: Codable {
    let type: String  // "spread" or "total"
    let team: String?  // "home" or "away" for spread bets
    let selection: String?  // "over" or "under" for total bets
    let line: Double?  // The spread line or total line
    let odds: Int  // American odds

    // For spread bets
    static func spread(team: String, line: Double, odds: Int) -> BetDetail {
        BetDetail(type: "spread", team: team, selection: nil, line: line, odds: odds)
    }

    // For total bets
    static func total(selection: String, line: Double, odds: Int) -> BetDetail {
        BetDetail(type: "total", team: nil, selection: selection, line: line, odds: odds)
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