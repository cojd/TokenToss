//
//  Group.swift
//  TokenToss
//
//  Friend-first betting groups and rivalry system
//

import Foundation

// MARK: - Group

struct Group: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let createdBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    let seasonYear: Int
    let memberLimit: Int

    // Group personality
    let trashTalkEnabled: Bool
    let weeklyTokenAllowance: Int
    let allowanceDay: String
    let groupImageUrl: String?

    let isActive: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case seasonYear = "season_year"
        case memberLimit = "member_limit"
        case trashTalkEnabled = "trash_talk_enabled"
        case weeklyTokenAllowance = "weekly_token_allowance"
        case allowanceDay = "allowance_day"
        case groupImageUrl = "group_image_url"
        case isActive = "is_active"
        case description
    }
}

// MARK: - Group Summary (with member count)

struct GroupSummary: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdBy: UUID?
    let createdAt: Date
    let seasonYear: Int
    let memberLimit: Int
    let memberCount: Int
    let creatorUsername: String?
    let trashTalkEnabled: Bool
    let weeklyTokenAllowance: Int
    let groupImageUrl: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case seasonYear = "season_year"
        case memberLimit = "member_limit"
        case memberCount = "member_count"
        case creatorUsername = "creator_username"
        case trashTalkEnabled = "trash_talk_enabled"
        case weeklyTokenAllowance = "weekly_token_allowance"
        case groupImageUrl = "group_image_url"
        case description
    }

    var isFull: Bool {
        memberCount >= memberLimit
    }

    var spotsRemaining: Int {
        max(0, memberLimit - memberCount)
    }
}

// MARK: - Group Member

struct GroupMember: Codable, Identifiable {
    let groupId: UUID
    let userId: UUID
    let joinedAt: Date
    let displayName: String?
    let role: MemberRole
    let isActive: Bool

    var id: String {
        "\(groupId.uuidString)-\(userId.uuidString)"
    }

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case displayName = "display_name"
        case role
        case isActive = "is_active"
    }

    enum MemberRole: String, Codable {
        case admin
        case member
    }
}

// MARK: - Group Member Detailed (with stats)

struct GroupMemberDetailed: Codable, Identifiable {
    let groupId: UUID
    let userId: UUID
    let joinedAt: Date
    let displayName: String?
    let role: String
    let isActive: Bool
    let username: String
    let tokens: Int64
    let totalBets: Int
    let betsWon: Int
    let betsLost: Int

    var id: String {
        "\(groupId.uuidString)-\(userId.uuidString)"
    }

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case displayName = "display_name"
        case role
        case isActive = "is_active"
        case username
        case tokens
        case totalBets = "total_bets"
        case betsWon = "bets_won"
        case betsLost = "bets_lost"
    }

    var winRate: Double {
        let settled = betsWon + betsLost
        guard settled > 0 else { return 0 }
        return Double(betsWon) / Double(settled) * 100
    }

    var record: String {
        "\(betsWon)-\(betsLost)"
    }
}

// MARK: - Group Invitation

struct GroupInvitation: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let invitedBy: UUID
    let invitedUserId: UUID
    let status: InvitationStatus
    let createdAt: Date
    let respondedAt: Date?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case invitedBy = "invited_by"
        case invitedUserId = "invited_user_id"
        case status
        case createdAt = "created_at"
        case respondedAt = "responded_at"
        case expiresAt = "expires_at"
    }

    enum InvitationStatus: String, Codable {
        case pending
        case accepted
        case declined
        case expired
    }

    var isExpired: Bool {
        expiresAt < Date()
    }

    var isPending: Bool {
        status == .pending && !isExpired
    }
}

// MARK: - Group Leaderboard Entry

struct GroupLeaderboardEntry: Codable, Identifiable, Hashable {
    let groupId: UUID
    let userId: UUID
    let username: String
    let displayName: String?
    let balance: Int64
    let wins: Int
    let losses: Int
    let pending: Int
    let totalWagered: Int64
    let totalProfit: Int64
    let winPercentage: Double

    var id: String {
        "\(groupId.uuidString)-\(userId.uuidString)"
    }

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case balance
        case wins
        case losses
        case pending
        case totalWagered = "total_wagered"
        case totalProfit = "total_profit"
        case winPercentage = "win_percentage"
    }

    var record: String {
        "\(wins)-\(losses)"
    }

    var displayUsername: String {
        displayName ?? username
    }
}

// MARK: - Rivalry Stats

struct RivalryStats: Codable {
    let user1: RivalryUser
    let user2: RivalryUser
    let stats: RivalryStatsDetail
    let recentMatchups: [RivalryMatchup]

    enum CodingKeys: String, CodingKey {
        case user1
        case user2
        case stats
        case recentMatchups = "recent_matchups"
    }
}

struct RivalryUser: Codable {
    let id: UUID
    let username: String
}

struct RivalryStatsDetail: Codable {
    let totalMatchups: Int
    let user1Wins: Int
    let user2Wins: Int
    let bothWon: Int
    let bothLost: Int
    let user1TotalProfit: Int64
    let user2TotalProfit: Int64
    let biggestUser1Win: Int64
    let biggestUser2Win: Int64
    let lastMatchupDate: Date?
    let oppositePicksCount: Int

    enum CodingKeys: String, CodingKey {
        case totalMatchups = "total_matchups"
        case user1Wins = "user1_wins"
        case user2Wins = "user2_wins"
        case bothWon = "both_won"
        case bothLost = "both_lost"
        case user1TotalProfit = "user1_total_profit"
        case user2TotalProfit = "user2_total_profit"
        case biggestUser1Win = "biggest_user1_win"
        case biggestUser2Win = "biggest_user2_win"
        case lastMatchupDate = "last_matchup_date"
        case oppositePicksCount = "opposite_picks_count"
    }
}

struct RivalryMatchup: Codable, Identifiable {
    let gameId: UUID
    let homeTeam: String
    let awayTeam: String
    let commenceTime: Date
    let user1Pick: String
    let user2Pick: String
    let user1Result: String
    let user2Result: String
    let user1Profit: Int64
    let user2Profit: Int64

    var id: UUID { gameId }

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case commenceTime = "commence_time"
        case user1Pick = "user1_pick"
        case user2Pick = "user2_pick"
        case user1Result = "user1_result"
        case user2Result = "user2_result"
        case user1Profit = "user1_profit"
        case user2Profit = "user2_profit"
    }
}

// MARK: - Rivalry Summary (for list view)

struct RivalrySummary: Codable, Identifiable {
    let rivalId: UUID
    let rivalUsername: String
    let matchups: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let winRate: Double
    let profitDiff: Int64
    let lastMatchup: Date?

    var id: UUID { rivalId }

    enum CodingKeys: String, CodingKey {
        case rivalId = "rival_id"
        case rivalUsername = "rival_username"
        case matchups
        case wins
        case losses
        case ties
        case winRate = "win_rate"
        case profitDiff = "profit_diff"
        case lastMatchup = "last_matchup"
    }

    var record: String {
        "\(wins)-\(losses)-\(ties)"
    }

    var isWinning: Bool {
        wins > losses
    }
}

// MARK: - Response Models

struct JoinGroupResponse: Codable {
    let success: Bool
    let groupId: UUID?
    let userId: UUID?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case groupId = "group_id"
        case userId = "user_id"
        case error
    }
}

struct LeaveGroupResponse: Codable {
    let success: Bool
    let error: String?
}

struct GrantAllowanceResponse: Codable {
    let success: Bool
    let membersUpdated: Int?
    let allowanceAmount: Int?
    let error: String?
    let currentDay: String?
    let allowanceDay: String?

    enum CodingKeys: String, CodingKey {
        case success
        case membersUpdated = "members_updated"
        case allowanceAmount = "allowance_amount"
        case error
        case currentDay = "current_day"
        case allowanceDay = "allowance_day"
    }
}
