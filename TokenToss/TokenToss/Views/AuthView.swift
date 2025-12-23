//
//  AuthView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.tokenGold.opacity(0.1),
                        Color.tokenBronze.opacity(0.05),
                        Color.appBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer()
                            .frame(height: 40)
                        
                        // Logo with coin animation
                        VStack(spacing: 20) {
                            CoinTossIcon(size: 100)
                            
                            Text("Token Toss")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(LinearGradient.tokenGradient)
                            
                            Text("Toss tokens, win big!")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 30)
                
                // Form fields
                VStack(spacing: 16) {
                    if isSignUp {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.tokenGold)
                                .frame(width: 24)
                            TextField("Username", text: $username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.tokenGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.tokenGold)
                            .frame(width: 24)
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.tokenGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.tokenGold)
                            .frame(width: 24)
                        SecureField("Password", text: $password)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.tokenGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Error message
                if let error = authVM.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .foregroundColor(.lossRed)
                    .font(.caption)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lossRed.opacity(0.1))
                    )
                    .padding(.horizontal)
                }
                
                // Action button
                Button(action: {
                    print("🔵 [DEBUG] Sign Up button tapped")
                    Task {
                        print("🔵 [DEBUG] Task started, isSignUp: \(isSignUp)")
                        if isSignUp {
                            print("🔵 [DEBUG] Calling signUp...")
                            await authVM.signUp(
                                email: email,
                                password: password,
                                username: username
                            )
                            print("🔵 [DEBUG] signUp returned")
                        } else {
                            print("🔵 [DEBUG] Calling signIn...")
                            await authVM.signIn(
                                email: email,
                                password: password
                            )
                            print("🔵 [DEBUG] signIn returned")
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        if authVM.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            TokenIcon(size: 24, color: .white.opacity(0.9))
                            Text(isSignUp ? "Start Tossing" : "Sign In")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.tokenGradient)
                            .shadow(color: Color.tokenGold.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                .disabled(authVM.isLoading || email.isEmpty || password.isEmpty || (isSignUp && username.isEmpty))
                
                // Toggle sign up / sign in
                Button(action: {
                    // #region agent log
                    Task {
                        let logData: [String: Any] = [
                            "sessionId": "debug-session",
                            "runId": "run1",
                            "hypothesisId": "A",
                            "location": "AuthView.swift:100",
                            "message": "Toggle sign up/sign in button tapped",
                            "data": ["isSignUp": isSignUp, "errorMessageExists": authVM.errorMessage != nil],
                            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                        ]
                        if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
                           let url = URL(string: "http://127.0.0.1:7242/ingest/731f5da9-ed96-4291-b469-2ffd89bb93f3") {
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            request.httpBody = jsonData
                            _ = try? await URLSession.shared.data(for: request)
                        }
                    }
                    // #endregion
                    withAnimation {
                        isSignUp.toggle()
                        authVM.errorMessage = nil
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "New tosser? Sign Up")
                        .font(.footnote)
                        .foregroundColor(.tokenGold)
                        .fontWeight(.medium)
                }
                .padding(.top, 10)
                
                if !isSignUp {
                    HStack(spacing: 6) {
                        TokenIcon(size: 20, color: .winGreen)
                        Text("Sign up to get 1,000 free tokens!")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.winGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.winGreen.opacity(0.15))
                    )
                    .padding(.top, 5)
                }
                
                // MARK: - Test Account Button (Development Only)
                #if DEBUG
                Divider()
                    .padding(.vertical, 20)
                
                VStack(spacing: 8) {
                    Text("⚡️ Quick Testing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        Task {
                            await authVM.useTestAccount()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                            Text("Use Test Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tokenAccent.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.tokenAccent.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                    .foregroundColor(.tokenAccent)
                    .padding(.horizontal)
                    .disabled(authVM.isLoading)
                    
                    Text("admin@tokentoss.app / testing123")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                #endif
                
                Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}
