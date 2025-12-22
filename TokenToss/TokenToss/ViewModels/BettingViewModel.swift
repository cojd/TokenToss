//
//  BettingViewModel.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI
import Supabase
import Combine

@MainActor
class BettingViewModel: ObservableObject {
    @Published var bets: [Bet] = []
    @Published var isPlacingBet = false
    @Published var isLoadingBets = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    func placeBet(gameId: UUID, teamBetOn: String, wagerAmount: Int64, oddsAtBet: Int) async -> Bool {
        isPlacingBet = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // Call the database function
            let response: [PlaceBetResponse] = try await supabase
                .rpc(
                    "place_bet",
                    params: [
                        "p_user_id": userId.uuidString,
                        "p_game_id": gameId.uuidString,
                        "p_team_bet_on": teamBetOn,
                        "p_wager_amount": String(wagerAmount),
                        "p_odds_at_bet": String(oddsAtBet)
                    ]
                )
                .execute()
                .value
            
            if let result = response.first {
                if result.success {
                    successMessage = "Bet placed successfully!"
                    await loadUserBets()
                    
                    // Trigger haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    isPlacingBet = false
                    return true
                } else {
                    errorMessage = result.message
                }
            }
        } catch {
            errorMessage = "Failed to place bet: \(error.localizedDescription)"
        }
        
        isPlacingBet = false
        return false
    }
    
    func loadUserBets() async {
        isLoadingBets = true
        
        // #region agent log
        let logData1: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "B",
            "location": "BettingViewModel.swift:67",
            "message": "loadUserBets entry",
            "data": ["isLoadingBets": isLoadingBets],
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
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // #region agent log
            let logData2: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "B",
                "location": "BettingViewModel.swift:75",
                "message": "Before query execution",
                "data": ["userId": userId.uuidString, "query": "select *, game:nfl_games(*)"],
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
            
            let bets: [Bet] = try await supabase
                .from("bets")
                .select("*, game:nfl_games(*)")
                .eq("user_id", value: userId.uuidString)
                .order("placed_at", ascending: false)
                .execute()
                .value
            
            // #region agent log
            let logData3: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "B",
                "location": "BettingViewModel.swift:81",
                "message": "After query execution",
                "data": ["betsCount": bets.count],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData3 = try? JSONSerialization.data(withJSONObject: logData3),
               let url3 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var request3 = URLRequest(url: url3)
                request3.httpMethod = "POST"
                request3.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request3.httpBody = jsonData3
                _ = try? await URLSession.shared.data(for: request3)
            }
            // #endregion
            
            self.bets = bets
        } catch {
            // #region agent log
            let logData4: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "B",
                "location": "BettingViewModel.swift:83",
                "message": "loadUserBets error",
                "data": ["error": error.localizedDescription, "errorType": String(describing: type(of: error))],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData4 = try? JSONSerialization.data(withJSONObject: logData4),
               let url4 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var request4 = URLRequest(url: url4)
                request4.httpMethod = "POST"
                request4.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request4.httpBody = jsonData4
                _ = try? await URLSession.shared.data(for: request4)
            }
            // #endregion
            print("Failed to load bets: \(error)")
        }
        
        isLoadingBets = false
    }
    
    func calculatePotentialPayout(wager: Int64, odds: Int) -> Int64 {
        if odds > 0 {
            // Positive odds: profit = wager * (odds/100)
            return wager + (wager * Int64(odds) / 100)
        } else {
            // Negative odds: profit = wager * (100/abs(odds))
            return wager + (wager * 100 / Int64(abs(odds)))
        }
    }
}