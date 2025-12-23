//
//  CreateGroupView.swift
//  TokenToss
//
//  Group creation form
//

import SwiftUI

struct CreateGroupView: View {
    @ObservedObject var viewModel: GroupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var groupName = ""
    @State private var description = ""
    @State private var memberLimit = 15
    @State private var weeklyAllowance = 500
    @State private var trashTalkEnabled = true

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 50))
                                .foregroundColor(TokenTossTheme.gold)

                            Text("Create Your Group")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Set up a betting group for you and your friends")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top)

                        // Form
                        VStack(spacing: 20) {
                            // Group Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Group Name")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                TextField("e.g., Sunday Squad", text: $groupName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }

                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                TextField("Add a description...", text: $description, axis: .vertical)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .lineLimit(3...6)
                            }

                            // Member Limit
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Member Limit")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(memberLimit) people")
                                        .foregroundColor(TokenTossTheme.gold)
                                }

                                Slider(value: Binding(
                                    get: { Double(memberLimit) },
                                    set: { memberLimit = Int($0) }
                                ), in: 5...50, step: 1)
                                    .accentColor(TokenTossTheme.gold)

                                Text("Recommended: 5-15 for tight-knit competition")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            // Weekly Allowance
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Weekly Token Allowance")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(weeklyAllowance) tokens")
                                        .foregroundColor(TokenTossTheme.gold)
                                }

                                Slider(value: Binding(
                                    get: { Double(weeklyAllowance) },
                                    set: { weeklyAllowance = Int($0) }
                                ), in: 100...1000, step: 50)
                                    .accentColor(TokenTossTheme.gold)

                                Text("Everyone gets this amount every Sunday")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            // Trash Talk
                            Toggle(isOn: $trashTalkEnabled) {
                                VStack(alignment: .leading) {
                                    Text("Enable Trash Talk")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Show rivalry notifications and friendly banter")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: TokenTossTheme.gold))
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)

                        // Create Button
                        Button(action: createGroup) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                    Text("Create Group")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                        .background(groupName.isEmpty ? Color.gray : TokenTossTheme.gold)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .disabled(groupName.isEmpty || viewModel.isLoading)

                        // Error/Success Messages
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(TokenTossTheme.gold)
                }
            }
        }
    }

    private func createGroup() {
        Task {
            let success = await viewModel.createGroup(
                name: groupName,
                description: description.isEmpty ? nil : description,
                memberLimit: memberLimit,
                weeklyAllowance: weeklyAllowance,
                trashTalkEnabled: trashTalkEnabled
            )

            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.white)
            .cornerRadius(8)
            .accentColor(TokenTossTheme.gold)
    }
}
