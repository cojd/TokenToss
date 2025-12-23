//
//  NFLGame.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import Foundation

struct NFLGame: Codable, Identifiable {
    let id: UUID
    let externalId: String
    let homeTeam: String
    let awayTeam: String
    let commenceTime: Date
    let homeScore: Int?
    let awayScore: Int?
    let isCompleted: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case externalId = "external_id"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case commenceTime = "commence_time"
        case homeScore = "home_score"
        case awayScore = "away_score"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isLive: Bool {
        let now = Date()
        return commenceTime <= now && !isCompleted
    }
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: commenceTime)
    }
}

struct Odds: Codable, Identifiable {
    let id: UUID
    let gameId: UUID

    // Moneyline (kept for compatibility)
    let homeMoneyline: Int?
    let awayMoneyline: Int?

    // Spread (new - friend-first betting)
    let homeSpread: Double?
    let homeSpreadOdds: Int?
    let awaySpread: Double?
    let awaySpreadOdds: Int?

    // Totals (new - friend-first betting)
    let totalOverLine: Double?
    let totalOverOdds: Int?
    let totalUnderLine: Double?
    let totalUnderOdds: Int?

    let capturedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case homeMoneyline = "home_moneyline"
        case awayMoneyline = "away_moneyline"
        case homeSpread = "home_spread"
        case homeSpreadOdds = "home_spread_odds"
        case awaySpread = "away_spread"
        case awaySpreadOdds = "away_spread_odds"
        case totalOverLine = "total_over_line"
        case totalOverOdds = "total_over_odds"
        case totalUnderLine = "total_under_line"
        case totalUnderOdds = "total_under_odds"
        case capturedAt = "captured_at"
    }

    func formattedOdds(for team: String, isHome: Bool) -> String {
        let odds = isHome ? homeMoneyline : awayMoneyline
        guard let odds = odds else { return "N/A" }
        return odds > 0 ? "+\(odds)" : "\(odds)"
    }

    func formattedSpread(isHome: Bool) -> String {
        let spread = isHome ? homeSpread : awaySpread
        guard let spread = spread else { return "N/A" }
        return spread > 0 ? "+\(spread)" : "\(spread)"
    }

    func formattedSpreadOdds(isHome: Bool) -> String {
        let odds = isHome ? homeSpreadOdds : awaySpreadOdds
        guard let odds = odds else { return "N/A" }
        return odds > 0 ? "+\(odds)" : "\(odds)"
    }

    func formattedTotal(isOver: Bool) -> String {
        let line = isOver ? totalOverLine : totalUnderLine
        guard let line = line else { return "N/A" }
        return "\(line)"
    }

    func formattedTotalOdds(isOver: Bool) -> String {
        let odds = isOver ? totalOverOdds : totalUnderOdds
        guard let odds = odds else { return "N/A" }
        return odds > 0 ? "+\(odds)" : "\(odds)"
    }

    var hasSpread: Bool {
        homeSpread != nil && homeSpreadOdds != nil
    }

    var hasTotals: Bool {
        totalOverLine != nil && totalOverOdds != nil
    }
}