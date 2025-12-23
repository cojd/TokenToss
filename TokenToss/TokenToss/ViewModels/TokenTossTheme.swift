//
//  TokenTossTheme.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//

import SwiftUI

// MARK: - Token Toss Color Theme
extension Color {
    // Primary brand colors - Gold & Bronze token colors
    static let tokenGold = Color(red: 1.0, green: 0.84, blue: 0.0) // #FFD700
    static let tokenBronze = Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
    static let tokenSilver = Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
    
    // Team distinction colors
    static let homeTeamPrimary = Color(red: 0.2, green: 0.4, blue: 0.8) // Blue
    static let homeTeamLight = Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.15)
    static let awayTeamPrimary = Color(red: 0.9, green: 0.3, blue: 0.3) // Red
    static let awayTeamLight = Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.15)
    
    // Accent colors
    static let tokenAccent = Color(red: 1.0, green: 0.65, blue: 0.0) // Orange-gold
    static let winGreen = Color(red: 0.2, green: 0.8, blue: 0.3)
    static let lossRed = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    // Neutral backgrounds
    static let cardBackground = Color(.secondarySystemBackground)
    static let appBackground = Color(.systemBackground)
}

// MARK: - Gradient Styles
extension LinearGradient {
    static let tokenGradient = LinearGradient(
        colors: [Color.tokenGold, Color.tokenBronze],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let homeTeamGradient = LinearGradient(
        colors: [Color.homeTeamPrimary, Color.homeTeamPrimary.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let awayTeamGradient = LinearGradient(
        colors: [Color.awayTeamPrimary, Color.awayTeamPrimary.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Token Icon View
struct TokenIcon: View {
    var size: CGFloat = 30
    var color: Color = .tokenGold
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 2)
            
            Text("T")
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Coin Toss Animation View
struct CoinTossIcon: View {
    @State private var isFlipping = false
    var size: CGFloat = 40
    
    var body: some View {
        TokenIcon(size: size)
            .rotation3DEffect(
                .degrees(isFlipping ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isFlipping
            )
            .onAppear {
                isFlipping = true
            }
    }
}

// MARK: - Token Badge
struct TokenBadge: View {
    let amount: Int64
    var size: CGFloat = 16
    
    var body: some View {
        HStack(spacing: 4) {
            TokenIcon(size: size, color: .tokenGold)
            Text("\(amount)")
                .font(.system(size: size * 0.75, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Team Badge Style
struct TeamBadge: View {
    let teamName: String
    let isHome: Bool
    let odds: String?
    
    var teamColor: Color {
        isHome ? .homeTeamPrimary : .awayTeamPrimary
    }
    
    var teamGradient: LinearGradient {
        isHome ? .homeTeamGradient : .awayTeamGradient
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Team name with color accent
            HStack {
                Circle()
                    .fill(teamColor)
                    .frame(width: 8, height: 8)
                
                Text(teamName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // Odds with team color
            if let odds = odds {
                Text(odds)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(teamColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(teamColor.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(teamColor.opacity(0.3), lineWidth: 1.5)
                            )
                    )
            }
        }
    }
}

// MARK: - Toss Button Style
struct TossButtonStyle: ButtonStyle {
    var color: Color = .tokenGold
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card Style with Token Theme
struct TokenCardStyle: ViewModifier {
    var backgroundColor: Color = .cardBackground
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
    }
}

extension View {
    func tokenCard(backgroundColor: Color = .cardBackground) -> some View {
        modifier(TokenCardStyle(backgroundColor: backgroundColor))
    }
}

// MARK: - Token Pulse Animation
struct TokenPulseModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func tokenPulse() -> some View {
        modifier(TokenPulseModifier())
    }
}
