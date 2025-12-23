//
//  GroupSelectionView.swift
//  TokenToss
//
//  Group selection/creation for users without a group
//

import SwiftUI

struct GroupSelectionView: View {
    @StateObject private var viewModel: GroupViewModel
    @State private var showCreateGroup = false

    init(userId: UUID) {
        _viewModel = StateObject(wrappedValue: GroupViewModel(userId: userId))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(TokenTossTheme.gold)

                        Text("Join a Group to Start")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Compete with your friends in small, tight-knit betting groups")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Create Group Button
                    Button(action: {
                        showCreateGroup = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Create New Group")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TokenTossTheme.gold)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Pending Invitations
                    if !viewModel.pendingInvitations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pending Invitations")
                                .font(.headline)
                                .foregroundColor(.white)

                            ForEach(viewModel.pendingInvitations) { invitation in
                                InvitationCard(
                                    invitation: invitation,
                                    onAccept: {
                                        Task {
                                            _ = await viewModel.acceptInvitation(invitation)
                                        }
                                    },
                                    onDecline: {
                                        Task {
                                            _ = await viewModel.declineInvitation(invitation)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()

                    // Info section
                    VStack(spacing: 8) {
                        InfoRow(icon: "checkmark.circle.fill", text: "5-15 person groups")
                        InfoRow(icon: "checkmark.circle.fill", text: "Track rivalries with each friend")
                        InfoRow(icon: "checkmark.circle.fill", text: "Simple spread & total bets")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadPendingInvitations()
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(TokenTossTheme.gold)
            Text(text)
                .foregroundColor(.gray)
            Spacer()
        }
    }
}

struct InvitationCard: View {
    let invitation: GroupInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group Invitation")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                Button(action: onAccept) {
                    Text("Accept")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TokenTossTheme.gold)
                        .cornerRadius(8)
                }

                Button(action: onDecline) {
                    Text("Decline")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
