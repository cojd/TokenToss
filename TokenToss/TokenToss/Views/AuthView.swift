//
//  AuthView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("BetBuddy")
                    .font(.largeTitle)
                    .bold()
                
                Text("Bet with friends using virtual tokens")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Form fields
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Action button
                Button(action: {
                    print("🔵 [DEBUG] Sign Up button tapped")
                    Task {
                        print("🔵 [DEBUG] Task started, isSignUp: \(isSignUp)")
                        if isSignUp {
                            print("🔵 [DEBUG] Calling signUp...")
                            await viewModel.signUp(
                                email: email,
                                password: password,
                                username: username
                            )
                            print("🔵 [DEBUG] signUp returned")
                        } else {
                            print("🔵 [DEBUG] Calling signIn...")
                            await viewModel.signIn(
                                email: email,
                                password: password
                            )
                            print("🔵 [DEBUG] signIn returned")
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty || (isSignUp && username.isEmpty))
                
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
                            "data": ["isSignUp": isSignUp, "errorMessageExists": viewModel.errorMessage != nil],
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
                        viewModel.errorMessage = nil
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                .padding(.top, 10)
                
                if !isSignUp {
                    Text("Sign up to get 1,000 free tokens!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 5)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}