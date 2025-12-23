//
//  GroupViewModel.swift
//  TokenToss
//
//  Group management and rivalry tracking for friend-first betting
//

import SwiftUI
import Supabase
import Combine

@MainActor
class GroupViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentGroup: GroupSummary?
    @Published var userGroups: [GroupSummary] = []
    @Published var groupMembers: [GroupMemberDetailed] = []
    @Published var pendingInvitations: [GroupInvitation] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let userId: UUID

    // MARK: - Initialization

    init(userId: UUID) {
        self.userId = userId
        Task {
            await loadUserGroups()
        }
    }

    // MARK: - Group Loading

    func loadUserGroups() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get all groups user is a member of
            let memberships: [GroupMember] = try await supabase
                .from("group_members")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            let groupIds = memberships.map { $0.groupId.uuidString }

            if !groupIds.isEmpty {
                // Get detailed group info
                let groups: [GroupSummary] = try await supabase
                    .from("groups_summary")
                    .select()
                    .in("id", values: groupIds)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                userGroups = groups

                // Set current group if not set (first group by default)
                if currentGroup == nil, let firstGroup = groups.first {
                    currentGroup = firstGroup
                    await loadGroupMembers(groupId: firstGroup.id)
                }
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to load groups: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func loadGroupMembers(groupId: UUID) async {
        do {
            let members: [GroupMemberDetailed] = try await supabase
                .from("group_members_detailed")
                .select()
                .eq("group_id", value: groupId.uuidString)
                .eq("is_active", value: true)
                .order("tokens", ascending: false)
                .execute()
                .value

            groupMembers = members
        } catch {
            errorMessage = "Failed to load group members: \(error.localizedDescription)"
        }
    }

    func loadPendingInvitations() async {
        do {
            let invitations: [GroupInvitation] = try await supabase
                .from("group_invitations")
                .select()
                .eq("invited_user_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .execute()
                .value

            pendingInvitations = invitations.filter { !$0.isExpired }
        } catch {
            errorMessage = "Failed to load invitations: \(error.localizedDescription)"
        }
    }

    // MARK: - Group Creation

    func createGroup(
        name: String,
        description: String?,
        memberLimit: Int = 15,
        weeklyAllowance: Int = 500,
        trashTalkEnabled: Bool = true
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let currentYear = Calendar.current.component(.year, from: Date())

            // Create group
            let newGroup: [Group] = try await supabase
                .from("groups")
                .insert([
                    "name": name,
                    "created_by": userId.uuidString,
                    "description": description ?? "",
                    "member_limit": memberLimit,
                    "season_year": currentYear,
                    "weekly_token_allowance": weeklyAllowance,
                    "trash_talk_enabled": trashTalkEnabled
                ])
                .select()
                .execute()
                .value

            guard let group = newGroup.first else {
                throw NSError(domain: "GroupViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create group"])
            }

            // Add creator as admin member
            let _: [GroupMember] = try await supabase
                .from("group_members")
                .insert([
                    "group_id": group.id.uuidString,
                    "user_id": userId.uuidString,
                    "role": "admin"
                ])
                .select()
                .execute()
                .value

            successMessage = "Group '\(name)' created successfully!"
            isLoading = false

            // Reload groups
            await loadUserGroups()

            return true
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Joining Groups

    func joinGroup(groupId: UUID, invitationId: UUID? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result: JoinGroupResponse = try await supabase.rpc(
                "join_group",
                params: [
                    "group_id_param": groupId.uuidString,
                    "user_id_param": userId.uuidString,
                    "invitation_id_param": invitationId?.uuidString as Any
                ]
            ).execute().value

            if result.success {
                successMessage = "Successfully joined group!"
                await loadUserGroups()
                isLoading = false
                return true
            } else {
                errorMessage = result.error ?? "Failed to join group"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Failed to join group: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func leaveGroup(groupId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result: LeaveGroupResponse = try await supabase.rpc(
                "leave_group",
                params: [
                    "group_id_param": groupId.uuidString,
                    "user_id_param": userId.uuidString
                ]
            ).execute().value

            if result.success {
                successMessage = "Left group successfully"
                await loadUserGroups()
                isLoading = false
                return true
            } else {
                errorMessage = result.error ?? "Failed to leave group"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Failed to leave group: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Group Invitations

    func inviteUserToGroup(groupId: UUID, invitedUserId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let _: [GroupInvitation] = try await supabase
                .from("group_invitations")
                .insert([
                    "group_id": groupId.uuidString,
                    "invited_by": userId.uuidString,
                    "invited_user_id": invitedUserId.uuidString
                ])
                .select()
                .execute()
                .value

            successMessage = "Invitation sent!"
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to send invitation: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func acceptInvitation(_ invitation: GroupInvitation) async -> Bool {
        return await joinGroup(groupId: invitation.groupId, invitationId: invitation.id)
    }

    func declineInvitation(_ invitation: GroupInvitation) async -> Bool {
        do {
            try await supabase
                .from("group_invitations")
                .update([
                    "status": "declined",
                    "responded_at": Date().ISO8601Format()
                ])
                .eq("id", value: invitation.id.uuidString)
                .execute()

            await loadPendingInvitations()
            return true
        } catch {
            errorMessage = "Failed to decline invitation: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Group Selection

    func selectGroup(_ group: GroupSummary) async {
        currentGroup = group
        await loadGroupMembers(groupId: group.id)
    }

    // MARK: - Rivalry Functions

    func getRivalryStats(withUser rivalId: UUID) async -> RivalryStats? {
        guard let groupId = currentGroup?.id else { return nil }

        do {
            let stats: RivalryStats = try await supabase.rpc(
                "get_rivalry_stats",
                params: [
                    "p_group_id": groupId.uuidString,
                    "p_user1_id": userId.uuidString,
                    "p_user2_id": rivalId.uuidString
                ]
            ).execute().value

            return stats
        } catch {
            print("Failed to load rivalry stats: \(error)")
            return nil
        }
    }

    func getAllRivalries() async -> [RivalrySummary] {
        guard let groupId = currentGroup?.id else { return [] }

        do {
            let rivalries: [RivalrySummary] = try await supabase.rpc(
                "get_user_rivalries",
                params: [
                    "p_group_id": groupId.uuidString,
                    "p_user_id": userId.uuidString
                ]
            ).execute().value

            return rivalries
        } catch {
            print("Failed to load rivalries: \(error)")
            return []
        }
    }

    // MARK: - Helper Functions

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    var hasGroup: Bool {
        !userGroups.isEmpty
    }

    var needsToJoinGroup: Bool {
        userGroups.isEmpty
    }
}
