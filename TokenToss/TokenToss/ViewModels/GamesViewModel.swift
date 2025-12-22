//
//  GamesViewModel.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


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
    
    private let oddsAPI = OddsAPIService.shared
    private var refreshTimer: Timer?
    
    func startAutoRefresh() {
        // Refresh every 60 seconds to conserve API calls
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshGames()
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
            // Fetch from API
            let apiGames = try await oddsAPI.fetchNFLGames()
            
            // Sync to database
            for apiGame in apiGames {
                await syncGameToDatabase(apiGame)
            }
            
            // Load from database
            await fetchGamesFromDatabase()
            
            lastUpdated = Date()
        } catch {
            errorMessage = "Failed to load games: \(error.localizedDescription)"
        }
        
        isLoading = false
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
                        "commence_time": String(commenceTime.timeIntervalSince1970)
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
            
            for bookmaker in apiGame.bookmakers {
                for market in bookmaker.markets where market.key == "h2h" {
                    for outcome in market.outcomes {
                        let americanOdds = oddsAPI.convertToAmericanOdds(decimal: outcome.price)
                        
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
                }
            }
            
            // Insert odds snapshot
            if bestHomeOdds != nil || bestAwayOdds != nil {
                var oddsParams: [String: String] = [
                    "game_id": gameId.uuidString
                ]
                if let homeOdds = bestHomeOdds {
                    oddsParams["home_moneyline"] = String(homeOdds)
                }
                if let awayOdds = bestAwayOdds {
                    oddsParams["away_moneyline"] = String(awayOdds)
                }
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
            let games: [NFLGame] = try await supabase
                .from("nfl_games")
                .select()
                .gte("commence_time", value: String(Date().timeIntervalSince1970 - 3600)) // Include games from 1 hour ago
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
        await loadGames()
    }
}