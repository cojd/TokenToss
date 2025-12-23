//
//  AuthViewModel.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI
import Supabase
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        Task {
            do {
                _ = try await supabase.auth.session
                self.isAuthenticated = true
                await fetchCurrentUser()
            } catch {
                self.isAuthenticated = false
            }
        }
    }
    
    func signUp(email: String, password: String, username: String) async {
        print("🔵 [DEBUG] signUp called with email: \(email), username: \(username)")
        isLoading = true
        errorMessage = nil
        
        defer {
            print("🔵 [DEBUG] signUp defer - setting isLoading to false")
            isLoading = false
        }
        
        // #region agent log
        let logDataStart: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "H",
            "location": "AuthViewModel.swift:38",
            "message": "signUp started",
            "data": ["email": email, "username": username],
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonDataStart = try? JSONSerialization.data(withJSONObject: logDataStart),
           let urlStart = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
            var requestStart = URLRequest(url: urlStart)
            requestStart.httpMethod = "POST"
            requestStart.setValue("application/json", forHTTPHeaderField: "Content-Type")
            requestStart.httpBody = jsonDataStart
            _ = try? await URLSession.shared.data(for: requestStart)
        }
        // #endregion
        
        do {
            // First check if username is taken
            print("🔵 [DEBUG] Starting username check query...")
            // #region agent log
            let logDataBeforeCheck: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "H",
                "location": "AuthViewModel.swift:56",
                "message": "Before username check query",
                "data": [:],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonDataBeforeCheck = try? JSONSerialization.data(withJSONObject: logDataBeforeCheck),
               let urlBeforeCheck = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var requestBeforeCheck = URLRequest(url: urlBeforeCheck)
                requestBeforeCheck.httpMethod = "POST"
                requestBeforeCheck.setValue("application/json", forHTTPHeaderField: "Content-Type")
                requestBeforeCheck.httpBody = jsonDataBeforeCheck
                _ = try? await URLSession.shared.data(for: requestBeforeCheck)
            }
            // #endregion
            
            print("🔵 [DEBUG] Executing Supabase query for username check...")
            
            let profiles: [User] = try await supabase
                .from("profiles")
                .select()
                .eq("username", value: username)
                .execute()
                .value
            
            print("🔵 [DEBUG] Username check completed, found \(profiles.count) profiles")
            
            // #region agent log
            let logDataAfterCheck: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "H",
                "location": "AuthViewModel.swift:91",
                "message": "After username check query",
                "data": ["profilesCount": profiles.count],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonDataAfterCheck = try? JSONSerialization.data(withJSONObject: logDataAfterCheck),
               let urlAfterCheck = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var requestAfterCheck = URLRequest(url: urlAfterCheck)
                requestAfterCheck.httpMethod = "POST"
                requestAfterCheck.setValue("application/json", forHTTPHeaderField: "Content-Type")
                requestAfterCheck.httpBody = jsonDataAfterCheck
                _ = try? await URLSession.shared.data(for: requestAfterCheck)
            }
            // #endregion
            
            if !profiles.isEmpty {
                print("🔴 [ERROR] Username already taken")
                errorMessage = "Username already taken"
                return
            }
            
            print("🔵 [DEBUG] Username available, proceeding with signup...")
            
            // Sign up user
            // #region agent log
            let logDataBeforeSignUp: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "H",
                "location": "AuthViewModel.swift:90",
                "message": "Before signUp call",
                "data": [:],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonDataBeforeSignUp = try? JSONSerialization.data(withJSONObject: logDataBeforeSignUp),
               let urlBeforeSignUp = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var requestBeforeSignUp = URLRequest(url: urlBeforeSignUp)
                requestBeforeSignUp.httpMethod = "POST"
                requestBeforeSignUp.setValue("application/json", forHTTPHeaderField: "Content-Type")
                requestBeforeSignUp.httpBody = jsonDataBeforeSignUp
                _ = try? await URLSession.shared.data(for: requestBeforeSignUp)
            }
            // #endregion
            
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            // #region agent log
            let logData0: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "G",
                "location": "AuthViewModel.swift:58",
                "message": "After signUp response",
                "data": [
                    "hasUser": true,
                    "hasSession": response.session != nil,
                    "userId": response.user.id.uuidString
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData0 = try? JSONSerialization.data(withJSONObject: logData0),
               let url0 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var request0 = URLRequest(url: url0)
                request0.httpMethod = "POST"
                request0.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request0.httpBody = jsonData0
                _ = try? await URLSession.shared.data(for: request0)
            }
            // #endregion
            
            // Update username
            let userId = response.user.id
            // #region agent log
            let logData1: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "G",
                "location": "AuthViewModel.swift:85",
                "message": "Before profile update",
                "data": ["userId": userId.uuidString, "username": username],
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
            
            try await supabase
                .from("profiles")
                .update(["username": username])
                .eq("id", value: userId.uuidString)
                .execute()
            
            // #region agent log
            let logData2: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "E",
                "location": "AuthViewModel.swift:70",
                "message": "After profile update",
                "data": ["success": true],
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
            
            // Check if session is available
            // #region agent log
            do {
                let sessionCheck = try? await supabase.auth.session
                let logData3: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "G",
                    "location": "AuthViewModel.swift:111",
                    "message": "Session check after signup",
                    "data": ["hasSession": sessionCheck != nil],
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
            }
            // #endregion
            
            // If session exists, authenticate and fetch user
            print("🔵 [DEBUG] Checking for session after signup...")
            do {
                _ = try await supabase.auth.session
                print("✅ [DEBUG] Session found, authenticating user...")
                isAuthenticated = true
                print("✅ [DEBUG] isAuthenticated set to: \(isAuthenticated)")
                await fetchCurrentUser()
                print("✅ [DEBUG] User fetched successfully")
            } catch {
                // Session not available yet (might need email confirmation)
                print("⚠️ [DEBUG] No session available, but user was created. Fetching user directly...")
                // Still mark as authenticated if we have a user
                isAuthenticated = true
                print("✅ [DEBUG] isAuthenticated set to: \(isAuthenticated) (no session)")
                // Fetch user using the userId from signup response
                do {
                    print("🔵 [DEBUG] Fetching user with userId: \(userId.uuidString)")
                    let user: User = try await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value
                    self.currentUser = user
                    print("✅ [DEBUG] User fetched successfully: \(user.username)")
                } catch let userError {
                    print("🔴 [ERROR] Error fetching user after signup: \(userError)")
                    print("🔴 [ERROR] Error type: \(type(of: userError))")
                    // Still authenticated even if we can't fetch user details yet
                }
            }
            
            print("🔵 [DEBUG] Signup flow complete. isAuthenticated: \(isAuthenticated), currentUser: \(currentUser?.username ?? "nil")")
        } catch {
            // #region agent log
            let logDataError: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "H",
                "location": "AuthViewModel.swift:262",
                "message": "signUp error",
                "data": [
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error)),
                    "errorDescription": String(describing: error)
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            Task {
                if let jsonDataError = try? JSONSerialization.data(withJSONObject: logDataError),
                   let urlError = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                    var requestError = URLRequest(url: urlError)
                    requestError.httpMethod = "POST"
                    requestError.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    requestError.httpBody = jsonDataError
                    _ = try? await URLSession.shared.data(for: requestError)
                }
            }
            // #endregion
            
            print("🔴 [ERROR] SignUp failed:")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
            print("   Type: \(type(of: error))")
            
            // Set user-friendly error message
            let errorMsg = error.localizedDescription.isEmpty ? "Failed to sign up. Please check your internet connection and try again." : error.localizedDescription
            errorMessage = errorMsg
        }
        
            print("🔵 [DEBUG] signUp completed successfully")
        }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
            isAuthenticated = true
            await fetchCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchCurrentUser() async {
        // #region agent log
        let logDataFetch: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "G",
            "location": "AuthViewModel.swift:148",
            "message": "fetchCurrentUser entry",
            "data": [:],
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonDataFetch = try? JSONSerialization.data(withJSONObject: logDataFetch),
           let urlFetch = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
            var requestFetch = URLRequest(url: urlFetch)
            requestFetch.httpMethod = "POST"
            requestFetch.setValue("application/json", forHTTPHeaderField: "Content-Type")
            requestFetch.httpBody = jsonDataFetch
            _ = try? await URLSession.shared.data(for: requestFetch)
        }
        // #endregion
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // #region agent log
            let logDataFetch2: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "G",
                "location": "AuthViewModel.swift:165",
                "message": "Got userId from session",
                "data": ["userId": userId.uuidString],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonDataFetch2 = try? JSONSerialization.data(withJSONObject: logDataFetch2),
               let urlFetch2 = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var requestFetch2 = URLRequest(url: urlFetch2)
                requestFetch2.httpMethod = "POST"
                requestFetch2.setValue("application/json", forHTTPHeaderField: "Content-Type")
                requestFetch2.httpBody = jsonDataFetch2
                _ = try? await URLSession.shared.data(for: requestFetch2)
            }
            // #endregion
            
            let user: User = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.currentUser = user
        } catch {
            // #region agent log
            let logDataFetchError: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "G",
                "location": "AuthViewModel.swift:185",
                "message": "fetchCurrentUser error",
                "data": ["error": error.localizedDescription, "errorType": String(describing: type(of: error))],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonDataFetchError = try? JSONSerialization.data(withJSONObject: logDataFetchError),
               let urlFetchError = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                var requestFetchError = URLRequest(url: urlFetchError)
                requestFetchError.httpMethod = "POST"
                requestFetchError.setValue("application/json", forHTTPHeaderField: "Content-Type")
                requestFetchError.httpBody = jsonDataFetchError
                _ = try? await URLSession.shared.data(for: requestFetchError)
            }
            // #endregion
            print("Error fetching user: \(error)")
        }
    }
    
    // MARK: - Testing Utilities
    
    /// Creates or signs in to the default test account
    /// Email: admin@tokentoss.app, Password: testing123, Username: admin
    func useTestAccount() async {
        print("🧪 Setting up test account...")
        isLoading = true
        errorMessage = nil
        
        let testEmail = "admin@tokentoss.app"
        let testPassword = "testing123"
        let testUsername = "admin"
        
        do {
            // First, try to sign in (in case account already exists)
            do {
                try await supabase.auth.signIn(
                    email: testEmail,
                    password: testPassword
                )
                print("✅ Signed in to existing test account")
                isAuthenticated = true
                await fetchCurrentUser()
                isLoading = false
                return
            } catch {
                // Account doesn't exist, create it
                print("📝 Test account doesn't exist, creating it...")
            }
            
            // Create the test account
            let response = try await supabase.auth.signUp(
                email: testEmail,
                password: testPassword
            )
            
            let userId = response.user.id
            
            // Update profile with username
            try await supabase
                .from("profiles")
                .update(["username": testUsername])
                .eq("id", value: userId.uuidString)
                .execute()
            
            print("✅ Test account created successfully")
            
            // Check for session and authenticate
            do {
                _ = try await supabase.auth.session
                isAuthenticated = true
                await fetchCurrentUser()
            } catch {
                // Session not available, but still authenticate
                isAuthenticated = true
                do {
                    let user: User = try await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value
                    self.currentUser = user
                } catch {
                    print("⚠️ Could not fetch user details, but account was created")
                }
            }
            
        } catch {
            print("❌ Failed to set up test account: \(error.localizedDescription)")
            errorMessage = "Failed to set up test account: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
