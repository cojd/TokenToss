//
//  GamesViewModel.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//

/*
 ODDS API CACHING STRATEGY

 Goal: Stay under 500 API calls/month (~16 calls/day max)

 Implementation:
 - Cache duration: 10 minutes (odds update every ~30 seconds on API, but we don't need that frequency)
 - Auto-refresh: Only refreshes from Supabase cache (no API calls)
 - Smart fetching: Only calls API when:
   1. Cache is expired (>10 minutes old)
   2. There are upcoming games that haven't started
   3. Games aren't completed

 Expected usage with this strategy:
 - ~3-4 API calls per day during NFL season
 - ~90-120 API calls per month
 - Well within 500/month limit ✅

 To force an API call (use sparingly):
 - Call forceRefreshFromAPI() instead of refreshGames()

 API usage is logged to 'api_usage_log' table in Supabase for monitoring.
 */

import SwiftUI
import Supabase
import Combine

@MainActor
class GamesViewModel: ObservableObject {
    @Published var games: [NFLGame] = []
    @Published var gameOdds: [UUID: Odds] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated = Date()
    @Published var lastApiCall: Date?

    private let oddsAPI = OddsAPIService.shared
    private var refreshTimer: Timer?

    // Cache duration: 10 minutes
    private let cacheDuration: TimeInterval = 10 * 60

    func startAutoRefresh() {
        // Refresh from cache every 60 seconds (no API calls)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshFromCache()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func loadGames() async {
        isLoading = true
        errorMessage = nil

        do {
            // First, try to load from cache
            await fetchGamesFromDatabase()

            // Determine if we need to call the API
            let shouldCallAPI = shouldFetchFromAPI()

            if shouldCallAPI {
                print("📞 Calling Odds API - cache expired")
                // Fetch from API
                let apiGames = try await oddsAPI.fetchNFLGames()

                // Sync to database
                for apiGame in apiGames {
                    await syncGameToDatabase(apiGame)
                }

                // Reload from database to get updated data
                await fetchGamesFromDatabase()

                // Track API call
                lastApiCall = Date()
                await logApiCall()
            } else {
                print("💾 Using cached data - API call skipped")
            }

            lastUpdated = Date()
        } catch {
            errorMessage = "Failed to load games: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func shouldFetchFromAPI() -> Bool {
        // Always fetch if we've never called the API
        guard let lastCall = lastApiCall else {
            return true
        }

        // Check if cache has expired (10 minutes)
        let timeSinceLastCall = Date().timeIntervalSince(lastCall)
        if timeSinceLastCall <= cacheDuration {
            return false
        }

        // Additional check: Only fetch if there are upcoming games that need fresh odds
        // Don't fetch if all games have started or completed
        let now = Date()
        let upcomingGames = games.filter { game in
            !game.isCompleted && game.commenceTime > now
        }

        // If no upcoming games, don't waste an API call
        if upcomingGames.isEmpty {
            print("⏭️ No upcoming games - skipping API call")
            return false
        }

        return true
    }

    private func refreshFromCache() async {
        // Only refresh from database, no API calls
        await fetchGamesFromDatabase()
        lastUpdated = Date()
    }

    private func logApiCall() async {
        // Log API usage to track monthly consumption
        do {
            struct APIUsageLog: Encodable {
                let endpoint: String
                let cost: Int
                let timestamp: String
            }
            
            let logEntry = APIUsageLog(
                endpoint: "americanfootball_nfl/odds",
                cost: 3, // 3 credits per call (1 region, 3 markets: h2h, spreads, totals)
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("api_usage_log")
                .insert(logEntry)
                .execute()
        } catch {
            print("Failed to log API usage: \(error)")
        }
    }
    
    private func syncGameToDatabase(_ apiGame: OddsAPIService.APIGame) async {
        do {
            // Parse datetime
            let formatter = ISO8601DateFormatter()
            guard let commenceTime = formatter.date(from: apiGame.commence_time) else {
                return
            }
            
            // Check if game exists
            let existingGames: [NFLGame] = try await supabase
                .from("nfl_games")
                .select()
                .eq("external_id", value: apiGame.id)
                .execute()
                .value
            
            let gameId: UUID
            
            if let existing = existingGames.first {
                gameId = existing.id
            } else {
                // Insert new game
                // #region agent log
                let logData1: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "D",
                    "location": "GamesViewModel.swift:84",
                    "message": "Before insert game",
                    "data": ["commenceTime": commenceTime.timeIntervalSince1970, "commenceTimeISO": ISO8601DateFormatter().string(from: commenceTime)],
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                ]
                if let jsonData1 = try? JSONSerialization.data(withJSONObject: logData1),
                   let url1 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                    var request1 = URLRequest(url: url1)
                    request1.httpMethod = "POST"
                    request1.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request1.httpBody = jsonData1
                    _ = try? await URLSession.shared.data(for: request1)
                }
                // #endregion
                
                let newGame: NFLGame = try await supabase
                    .from("nfl_games")
                    .insert([
                        "external_id": apiGame.id,
                        "home_team": apiGame.home_team,
                        "away_team": apiGame.away_team,
                        "commence_time": ISO8601DateFormatter().string(from: commenceTime)
                    ])
                    .select()
                    .single()
                    .execute()
                    .value
                
                // #region agent log
                let logData2: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "D",
                    "location": "GamesViewModel.swift:98",
                    "message": "After insert game",
                    "data": ["gameId": newGame.id.uuidString, "success": true],
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                ]
                if let jsonData2 = try? JSONSerialization.data(withJSONObject: logData2),
                   let url2 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                    var request2 = URLRequest(url: url2)
                    request2.httpMethod = "POST"
                    request2.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request2.httpBody = jsonData2
                    _ = try? await URLSession.shared.data(for: request2)
                }
                // #endregion
                
                gameId = newGame.id
            }
            
            // Extract best odds from bookmakers
            var bestHomeOdds: Int?
            var bestAwayOdds: Int?
            var bestHomeSpread: Double?
            var bestHomeSpreadOdds: Int?
            var bestAwaySpread: Double?
            var bestAwaySpreadOdds: Int?
            var bestTotalOverLine: Double?
            var bestTotalOverOdds: Int?
            var bestTotalUnderLine: Double?
            var bestTotalUnderOdds: Int?

            for bookmaker in apiGame.bookmakers {
                for market in bookmaker.markets {
                    if market.key == "h2h" {
                        // Moneyline odds
                        for outcome in market.outcomes {
                            let americanOdds = Int(outcome.price)

                            if outcome.name == apiGame.home_team {
                                if bestHomeOdds == nil || americanOdds > bestHomeOdds! {
                                    bestHomeOdds = americanOdds
                                }
                            } else if outcome.name == apiGame.away_team {
                                if bestAwayOdds == nil || americanOdds > bestAwayOdds! {
                                    bestAwayOdds = americanOdds
                                }
                            }
                        }
                    } else if market.key == "spreads" {
                        // Spread odds
                        for outcome in market.outcomes {
                            let americanOdds = Int(outcome.price)
                            guard let point = outcome.point else { continue }

                            if outcome.name == apiGame.home_team {
                                if bestHomeSpread == nil || americanOdds > (bestHomeSpreadOdds ?? Int.min) {
                                    bestHomeSpread = point
                                    bestHomeSpreadOdds = americanOdds
                                }
                            } else if outcome.name == apiGame.away_team {
                                if bestAwaySpread == nil || americanOdds > (bestAwaySpreadOdds ?? Int.min) {
                                    bestAwaySpread = point
                                    bestAwaySpreadOdds = americanOdds
                                }
                            }
                        }
                    } else if market.key == "totals" {
                        // Total (over/under) odds
                        for outcome in market.outcomes {
                            let americanOdds = Int(outcome.price)
                            guard let point = outcome.point else { continue }

                            if outcome.name == "Over" {
                                if bestTotalOverLine == nil || americanOdds > (bestTotalOverOdds ?? Int.min) {
                                    bestTotalOverLine = point
                                    bestTotalOverOdds = americanOdds
                                }
                            } else if outcome.name == "Under" {
                                if bestTotalUnderLine == nil || americanOdds > (bestTotalUnderOdds ?? Int.min) {
                                    bestTotalUnderLine = point
                                    bestTotalUnderOdds = americanOdds
                                }
                            }
                        }
                    }
                }
            }

            // Insert odds snapshot with all market types
            var oddsParams: [String: Any] = [
                "game_id": gameId.uuidString
            ]

            // Moneyline
            if let homeOdds = bestHomeOdds {
                oddsParams["home_moneyline"] = homeOdds
            }
            if let awayOdds = bestAwayOdds {
                oddsParams["away_moneyline"] = awayOdds
            }

            // Spreads
            if let homeSpread = bestHomeSpread {
                oddsParams["home_spread"] = homeSpread
            }
            if let homeSpreadOdds = bestHomeSpreadOdds {
                oddsParams["home_spread_odds"] = homeSpreadOdds
            }
            if let awaySpread = bestAwaySpread {
                oddsParams["away_spread"] = awaySpread
            }
            if let awaySpreadOdds = bestAwaySpreadOdds {
                oddsParams["away_spread_odds"] = awaySpreadOdds
            }

            // Totals
            if let overLine = bestTotalOverLine {
                oddsParams["total_over_line"] = overLine
            }
            if let overOdds = bestTotalOverOdds {
                oddsParams["total_over_odds"] = overOdds
            }
            if let underLine = bestTotalUnderLine {
                oddsParams["total_under_line"] = underLine
            }
            if let underOdds = bestTotalUnderOdds {
                oddsParams["total_under_odds"] = underOdds
            }

            if !oddsParams.isEmpty && oddsParams.count > 1 {
                try await supabase
                    .from("odds")
                    .insert(oddsParams)
                    .execute()
            }
            
        } catch {
            print("Error syncing game: \(error)")
        }
    }
    
    private func fetchGamesFromDatabase() async {
        do {
            // Get upcoming games
            let oneHourAgo = Date(timeIntervalSinceNow: -3600)
            let games: [NFLGame] = try await supabase
                .from("nfl_games")
                .select()
                .gte("commence_time", value: ISO8601DateFormatter().string(from: oneHourAgo)) // Include games from 1 hour ago
                .order("commence_time", ascending: true)
                .limit(20)
                .execute()
                .value
            
            self.games = games
            
            // Fetch latest odds for each game
            for game in games {
                let odds: [Odds] = try await supabase
                    .from("odds")
                    .select()
                    .eq("game_id", value: game.id.uuidString)
                    .order("captured_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                if let latestOdds = odds.first {
                    gameOdds[game.id] = latestOdds
                }
            }
        } catch {
            print("Error fetching games from database: \(error)")
        }
    }
    
    func refreshGames() async {
        // User-initiated refresh - respects cache
        await loadGames()
    }

    func forceRefreshFromAPI() async {
        // Force API call (use sparingly)
        lastApiCall = nil
        await loadGames()
    }
}
