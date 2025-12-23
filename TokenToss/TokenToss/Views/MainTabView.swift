//
//  MainTabView.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//


import SwiftUI

struct MainTabView: View { // Change 'Scene' to 'View' here
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View { // Change 'some Scene' to 'some View' here
        TabView(selection: $selectedTab) {
            GamesListView()
                .tabItem {
                    Label("Toss", systemImage: selectedTab == 0 ? "circle.hexagongrid.circle.fill" : "circle.hexagongrid.circle")
                }
                .tag(0)
            
            BetHistoryView()
                .tabItem {
                    Label("My Tosses", systemImage: selectedTab == 1 ? "list.bullet.clipboard.fill" : "list.bullet.clipboard")
                }
                .tag(1)
            
            WalletView()
                .tabItem {
                    Label("Tokens", systemImage: selectedTab == 2 ? "centsign.circle.fill" : "centsign.circle")
                }
                .tag(2)
            
            LeaderboardView()
                .tabItem {
                    Label("Leaders", systemImage: selectedTab == 3 ? "trophy.fill" : "trophy")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 4 ? "person.crop.circle.fill" : "person.crop.circle")
                }
                .tag(4)
        }
        .accentColor(.tokenGold)
    }
}

// A simple Profile View to handle signing out
struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                List {
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.tokenGradient)
                                    .frame(width: 70, height: 70)
                                
                                Text(authVM.currentUser?.username.prefix(1).uppercased() ?? "T")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: Color.tokenGold.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authVM.currentUser?.username ?? "Token Tosser")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                HStack(spacing: 4) {
                                    TokenIcon(size: 16, color: .tokenGold)
                                    Text("Pro Tosser")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    Section("Account") {
                        Button(action: {
                            Task {
                                await authVM.signOut()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    Section("About Token Toss") {
                        HStack {
                            Label("Version", systemImage: "info.circle.fill")
                                .foregroundColor(.tokenGold)
                            Spacer()
                            Text("1.0.0 (MVP)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Theme", systemImage: "paintpalette.fill")
                                .foregroundColor(.tokenGold)
                            Spacer()
                            Text("Token Toss")
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
        }
    }
}
