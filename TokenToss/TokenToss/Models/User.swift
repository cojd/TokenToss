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
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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