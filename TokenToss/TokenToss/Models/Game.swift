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
    let homeMoneyline: Int?
    let awayMoneyline: Int?
    let capturedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case homeMoneyline = "home_moneyline"
        case awayMoneyline = "away_moneyline"
        case capturedAt = "captured_at"
    }
    
    func formattedOdds(for team: String, isHome: Bool) -> String {
        let odds = isHome ? homeMoneyline : awayMoneyline
        guard let odds = odds else { return "N/A" }
        return odds > 0 ? "+\(odds)" : "\(odds)"
    }
}