//
//  User.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let username: String
    let createdAt: Date
    let updatedAt: Date

    // New: Betting experience and onboarding
    let bettingExperience: BettingExperience?
    let totalBetsPlaced: Int?
    let onboardingCompleted: Bool?
    let firstBetDate: Date?
    let profileImageUrl: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case bettingExperience = "betting_experience"
        case totalBetsPlaced = "total_bets_placed"
        case onboardingCompleted = "onboarding_completed"
        case firstBetDate = "first_bet_date"
        case profileImageUrl = "profile_image_url"
        case displayName = "display_name"
    }

    enum BettingExperience: String, Codable {
        case newcomer
        case intermediate
        case experienced
    }

    var isNewcomer: Bool {
        bettingExperience == .newcomer || (totalBetsPlaced ?? 0) < 10
    }

    var shouldShowTips: Bool {
        isNewcomer
    }
}

struct Wallet: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let balance: Int64
    let lifetimeEarned: Int64
    let lifetimeSpent: Int64
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case balance
        case lifetimeEarned = "lifetime_earned"
        case lifetimeSpent = "lifetime_spent"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var formattedBalance: String {
        return "\(balance) tokens"
    }
}