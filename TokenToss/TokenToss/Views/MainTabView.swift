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
                    Label("Games", systemImage: "sportscourt")
                }
                .tag(0)
            
            BetHistoryView()
                .tabItem {
                    Label("My Bets", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
            
            WalletView()
                .tabItem {
                    Label("Wallet", systemImage: "creditcard")
                }
                .tag(2)
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "chart.bar")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(4)
        }
    }
}

// A simple Profile View to handle signing out
struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(authVM.currentUser?.username ?? "User")
                                .font(.headline)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Account") {
                    Button(action: {
                        Task {
                            await authVM.signOut()
                        }
                    }) {
                        Label("Sign Out", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
