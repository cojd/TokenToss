//
//  OddsAPIService.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import Foundation

class OddsAPIService {
    static let shared = OddsAPIService()

    private let apiKey = "9ff40096658c08faa1c349c7f10ff9d8" // TODO: Replace with your API key from the-odds-api.com
    private let baseURL = "https://api.the-odds-api.com/v4"
    private let session = URLSession.shared

    // Track API usage
    private(set) var requestsRemaining: Int?
    private(set) var requestsUsed: Int?
    
    struct APIGame: Codable {
        let id: String
        let sport_key: String
        let sport_title: String
        let commence_time: String
        let home_team: String
        let away_team: String
        let bookmakers: [Bookmaker]
    }
    
    struct Bookmaker: Codable {
        let key: String
        let title: String
        let markets: [Market]
    }
    
    struct Market: Codable {
        let key: String
        let outcomes: [Outcome]
    }
    
    struct Outcome: Codable {
        let name: String
        let price: Double
    }
    
    /// Fetches NFL games with odds from The Odds API
    /// WARNING: This counts against your API quota. Use caching in GamesViewModel.
    /// Target: <500 API calls/month (see GamesViewModel for caching logic)
    func fetchNFLGames() async throws -> [APIGame] {
        // #region agent log
        let logData1: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "C",
            "location": "OddsAPIService.swift:44",
            "message": "fetchNFLGames entry",
            "data": ["apiKey": apiKey, "apiKeyIsPlaceholder": apiKey == "YOUR_ODDS_API_KEY"],
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
        
        var components = URLComponents(string: "\(baseURL)/sports/americanfootball_nfl/odds")!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "regions", value: "us"),
            URLQueryItem(name: "markets", value: "h2h"), // moneyline only for MVP
            URLQueryItem(name: "oddsFormat", value: "american")
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        // #region agent log
        if let httpResponse = response as? HTTPURLResponse {
            let logData2: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "C",
                "location": "OddsAPIService.swift:59",
                "message": "API response received",
                "data": ["statusCode": httpResponse.statusCode, "dataSize": data.count],
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
        }
        // #endregion
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Track API usage from response headers
        if let remaining = httpResponse.value(forHTTPHeaderField: "x-requests-remaining"),
           let remainingInt = Int(remaining) {
            requestsRemaining = remainingInt
            print("📊 API Requests remaining: \(remaining)")
        }

        if let used = httpResponse.value(forHTTPHeaderField: "x-requests-used"),
           let usedInt = Int(used) {
            requestsUsed = usedInt
            print("📊 API Requests used: \(used)")
        }

        if let lastCost = httpResponse.value(forHTTPHeaderField: "x-requests-last") {
            print("📊 Last request cost: \(lastCost)")
        }

        return try JSONDecoder().decode([APIGame].self, from: data)
    }
}
