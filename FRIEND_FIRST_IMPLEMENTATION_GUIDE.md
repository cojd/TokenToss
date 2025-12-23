# Friend-First Betting Refactor - Implementation Guide

## 📋 Overview

This document tracks the progress of refactoring TokenToss into a friend-first betting app with:
- **Small group competition** (5-15 people)
- **Simplified betting** (spread + totals only)
- **Head-to-head rivalries**
- **Newcomer-friendly onboarding**

**Branch:** `claude/friend-first-betting-refactor-X8Yfn`

---

## ✅ Phase 1: Group Foundation (COMPLETE)

### Database Schema ✓
**Location:** `TokenToss/TokenToss/Database/`

Created 4 comprehensive migration files:

1. **001_groups_schema.sql** (314 lines)
   - `groups` table with member limits, weekly allowance, trash talk settings
   - `group_members` table with role-based access (admin/member)
   - `group_invitations` table with expiration
   - Functions: `join_group()`, `leave_group()`, `grant_weekly_allowance()`
   - Views: `group_members_detailed`, `groups_summary`

2. **002_bets_and_odds_enhancement.sql** (367 lines)
   - Added `group_id` to `bets` table (all bets now group-scoped)
   - Added `bet_detail` JSONB column for spread/total structured data
   - Added spread/total columns to `odds` table
   - Updated `place_bet()` to require group context
   - New functions: `settle_bet()`, `settle_game()`
   - Views: `group_leaderboard`, `group_game_bets`

3. **003_profiles_enhancement.sql** (182 lines)
   - Added `betting_experience` field (newcomer/intermediate/experienced)
   - Added `total_bets_placed`, `onboarding_completed`, `first_bet_date`
   - Added `preferences` JSONB for user settings
   - Functions: `update_user_experience_level()`, `should_show_betting_tips()`
   - Auto-trigger to update experience on bet placement

4. **004_rivalry_stats.sql** (328 lines)
   - `get_rivalry_stats()` - comprehensive 1v1 stats
   - `get_user_rivalries()` - all rivalries for a user
   - `get_game_betting_breakdown()` - who bet on which side
   - `get_post_game_results()` - post-game rivalry comparison
   - View: `rivalry_dominance`

**README.md** included with full documentation, migration instructions, and future enhancement ideas.

### Swift Models ✓
**Files Modified:**

1. **Models/Group.swift** (NEW - 258 lines)
   - `Group`, `GroupSummary`, `GroupMember`, `GroupMemberDetailed`
   - `GroupInvitation`, `GroupLeaderboardEntry`
   - `RivalryStats`, `RivalrySummary`, `RivalryMatchup`
   - Response models: `JoinGroupResponse`, `LeaveGroupResponse`, `GrantAllowanceResponse`

2. **Models/Bet.swift** (UPDATED)
   - Added `groupId: UUID?`
   - Added `betDetail: BetDetail?` for structured spread/total data
   - Added `betDescription` computed property for human-readable format
   - `BetDetail` struct with `.spread()` and `.total()` factory methods

3. **Models/User.swift** (UPDATED)
   - Added `bettingExperience: BettingExperience?`
   - Added `totalBetsPlaced`, `onboardingCompleted`, `firstBetDate`
   - Added `profileImageUrl`, `displayName`
   - Computed: `isNewcomer`, `shouldShowTips`

4. **Models/Game.swift** (UPDATED)
   - Added spread fields: `homeSpread`, `homeSpreadOdds`, `awaySpread`, `awaySpreadOdds`
   - Added total fields: `totalOverLine`, `totalOverOdds`, `totalUnderLine`, `totalUnderOdds`
   - Helper methods: `formattedSpread()`, `formattedTotal()`, `hasSpread`, `hasTotals`

### ViewModels ✓

1. **ViewModels/GroupViewModel.swift** (NEW - 257 lines)
   - Complete CRUD for groups
   - Group membership management (join/leave)
   - Invitation system (send/accept/decline)
   - Rivalry functions: `getRivalryStats()`, `getAllRivalries()`
   - Group selection and context management

### Views ✓

1. **Views/GroupSelectionView.swift** (NEW)
   - Shown to users without a group
   - Create new group or accept invitations
   - Educational content about group features

2. **Views/CreateGroupView.swift** (NEW)
   - Group creation form
   - Configure: name, description, member limit, weekly allowance, trash talk
   - Custom text field style matching app theme

3. **Views/RivalriesView.swift** (NEW)
   - List of all head-to-head rivalries
   - Win/loss records, profit differential
   - Tap for detailed rivalry breakdown
   - Recent matchup history

---

## ✅ Phase 2: Simplified Betting (API COMPLETE)

### API Integration ✓

1. **Services/OddsAPIService.swift** (UPDATED)
   - Changed markets from `"h2h"` to `"h2h,spreads,totals"`
   - Added `point: Double?` to `Outcome` model
   - Still uses smart caching (10-minute cache duration)

2. **ViewModels/GamesViewModel.swift** (UPDATED)
   - Process h2h, spreads, and totals markets
   - Extract best odds for each market type
   - Store all odds in database
   - Updated API cost: 3 credits per call (was 1)
   - Projected usage: 270-360 calls/month (still under 500 limit)

### Remaining UI Work 🚧

**Next Steps:**

1. **Update PlaceBetView** (or create SimplifiedPlaceBetView)
   - Remove moneyline betting option
   - Add spread betting UI
     - Show home/away spread lines
     - Visual explanation: "Team -7.5 means they must win by 8+ points"
   - Add totals betting UI
     - Show over/under line
     - Explanation: "Over 45.5 means combined score must be 46+"
   - Bet type selector: `[Spread] [Total]` toggle
   - Newcomer tips (show for first 5 bets):
     - Spread tip: "The spread levels the playing field. Pick who covers."
     - Total tip: "Will the teams score more (over) or less (under) than 45.5 combined?"

2. **Create BettingEducationView**
   - Accessible from Profile tab
   - Sections:
     - "What is a spread?"
     - "What is over/under?"
     - "How do odds work?"
     - "What happens in a push?"
   - Simple language, visual examples

3. **Update BettingViewModel**
   - Modify `placeBet()` to use new `place_bet()` RPC signature:
     ```swift
     await supabase.rpc(
       "place_bet",
       params: [
         "p_user_id": userId,
         "p_game_id": gameId,
         "p_group_id": groupId,  // NEW
         "p_bet_type": betType,  // "spread" or "total"
         "p_bet_detail": betDetail,  // JSONB
         "p_wager_amount": wagerAmount
       ]
     )
     ```

---

## 🚧 Phase 3: Friend Indicators (PARTIAL)

### Completed ✓
- RivalriesView with full head-to-head stats

### Remaining Work 🚧

1. **Update GamesListView / GameCard**
   - Show friend avatars on each side of bet
   - Example:
     ```
     [HomeTeam -7.5]  👤👤  [AwayTeam +7.5]
     ```
   - Fetch from `group_game_bets` view
   - Show count if >3 friends on one side

2. **Create PostGameResultsView**
   - Triggered after game settles
   - Show:
     - Your result (WIN/LOSS/PUSH)
     - Who you beat (list with profit amounts)
     - Who beat you (list with loss amounts)
     - Overall record for the week
   - Celebration UI for wins
   - Call `get_post_game_results()` RPC function

---

## 🚧 Phase 4: Group-Centric Navigation

### Remaining Work 🚧

1. **Update MainTabView.swift**
   - Replace tabs:
     ```swift
     Tab 1: Games (existing, keep mostly same)
     Tab 2: Standings (update to group leaderboard)
     Tab 3: Rivalries (NEW - use RivalriesView)
     Tab 4: Profile (keep, add group switcher)
     ```
   - Remove: WalletView as separate tab (integrate into Profile)
   - Add: Group context banner at top

2. **Create GroupContextBanner**
   - Always visible at top of screen
   - Shows: Group name, your rank, token balance
   - Tap to see group details
   - Example:
     ```
     [Sunday Squad] • Rank: 3/12 • 1,250 tokens
     ```

3. **Update LeaderboardView.swift**
   - Query `group_leaderboard` view instead of global
   - Filter by `currentGroup.id`
   - Add rivalry indicators:
     - Tap user to see your rivalry stats with them
     - Show arrow indicators for close competitors
   - Highlight your position prominently
   - Show "person above you" and "person below you" with emphasis

4. **Update AuthViewModel**
   - After successful signup/signin:
     - Check if user has a group
     - If no group: Show GroupSelectionView modal
     - If has group: Load into main app

5. **Update TokenTossApp.swift**
   - Show GroupSelectionView if `groupViewModel.needsToJoinGroup`
   - Otherwise show MainTabView

---

## 🎨 Visual Design Updates

### Theme Enhancements

1. **Update TokenTossTheme.swift** (if exists, or create)
   - Color palette:
     - Gold: Keep for primary actions
     - Win: Green (#4CAF50)
     - Loss: Red (#F44336)
     - Neutral: Gray
   - Typography:
     - Increase minimum font size to 16pt
     - Use SF Pro Rounded for friendly feel

2. **Component Updates**
   - **GameCard**: Larger team names, clear bet indicators
   - **BetHistoryCard**: Emphasize WIN/LOSS first, details second
   - **LeaderboardRow**: Show position change arrows, larger avatars

---

## 🧪 Testing Checklist

### Critical User Flows

- [ ] **New User Onboarding**
  1. Sign up → No group prompt appears
  2. Create first group OR accept invitation
  3. See group context banner immediately
  4. Place first bet → Educational tooltip appears
  5. Bet detail shows in bet history

- [ ] **Group Operations**
  1. Create group with custom settings
  2. Invite another user
  3. Accept invitation (from invited user)
  4. Leave group (non-admin)
  5. Try to leave as last admin (should fail)

- [ ] **Betting Flow**
  1. View game with spread and total odds
  2. Select spread bet → See line and odds
  3. Select total bet → See over/under
  4. Place bet → Deducts tokens
  5. Bet appears in history with group context

- [ ] **Rivalry Tracking**
  1. Two users bet on same game (opposite sides)
  2. Game completes and settles
  3. Both users see updated rivalry stats
  4. Rivalry appears in Rivalries tab
  5. Post-game results screen shows who won

- [ ] **Group Leaderboard**
  1. Shows only current group members
  2. Sorted by token balance
  3. Win/loss records accurate
  4. Your position highlighted

---

## 📊 Database Migration Instructions

### For New Installation

Run migrations in order:

```sql
-- In Supabase SQL Editor
\i TokenToss/TokenToss/Database/001_groups_schema.sql
\i TokenToss/TokenToss/Database/002_bets_and_odds_enhancement.sql
\i TokenToss/TokenToss/Database/003_profiles_enhancement.sql
\i TokenToss/TokenToss/Database/004_rivalry_stats.sql
```

### For Existing Installation

If you have existing users/bets, run migration script:

```sql
-- Create legacy groups for existing users
INSERT INTO groups (name, created_by, season_year)
SELECT CONCAT(p.username, '''s Group'), p.id, EXTRACT(YEAR FROM CURRENT_DATE)
FROM profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM group_members gm WHERE gm.user_id = p.id
);

-- Add users to their legacy groups
INSERT INTO group_members (group_id, user_id, role)
SELECT g.id, g.created_by, 'admin'
FROM groups g
WHERE g.name LIKE '%''s Group';

-- Update existing bets with group_id
UPDATE bets b
SET group_id = (
  SELECT gm.group_id
  FROM group_members gm
  WHERE gm.user_id = b.user_id
  AND gm.is_active = TRUE
  LIMIT 1
)
WHERE group_id IS NULL;
```

---

## 🚀 Deployment Checklist

Before merging to main:

- [ ] All database migrations tested in staging
- [ ] Existing user migration script tested
- [ ] API key for The Odds API configured
- [ ] All new models compile without errors
- [ ] GroupViewModel tested with real Supabase data
- [ ] At least 2 users can create groups and place bets
- [ ] Rivalry stats calculate correctly
- [ ] No breaking changes to existing bet history
- [ ] Updated README.md with new features

---

## 📝 Known Limitations & Future Work

### Current Limitations (V1)
- Users can only be in ONE group at a time
- No group chat/messaging
- No commissioner tools (kick members, edit settings after creation)
- No group challenges or tournaments
- Bet types limited to spread and totals (no parlays, teasers, props)

### Potential V2 Features
- Multi-group support (separate token balances per group)
- Group messaging and trash talk threads
- Weekly/season-long challenges within groups
- Achievement badges for rivalries
- Historical season archives
- Commissioner dashboard
- Group discovery (public vs private groups)
- Custom bet types (props, player stats)
- Live betting updates during games

---

## 🆘 Troubleshooting

### Common Issues

**Issue:** Bets not showing group_id
- **Fix:** Ensure user is in a group first. Check `group_members` table.

**Issue:** Rivalry stats returning empty
- **Fix:** Need at least 2 users betting on same game for matchup to exist.

**Issue:** Odds not showing spread/totals
- **Fix:** Force API refresh with `forceRefreshFromAPI()` or check if bookmakers have those markets available.

**Issue:** Weekly allowance not granted
- **Fix:** Ensure it's the configured allowance day (default: Sunday). Check `grant_weekly_allowance()` function logs.

---

## 📚 Key Files Reference

### Database
- `Database/001_groups_schema.sql` - Core group infrastructure
- `Database/002_bets_and_odds_enhancement.sql` - Group betting + spreads/totals
- `Database/003_profiles_enhancement.sql` - Onboarding system
- `Database/004_rivalry_stats.sql` - Head-to-head tracking
- `Database/README.md` - Comprehensive documentation

### Models
- `Models/Group.swift` - All group-related models
- `Models/Bet.swift` - Updated with group context
- `Models/User.swift` - Betting experience tracking
- `Models/Game.swift` - Spread/totals odds

### ViewModels
- `ViewModels/GroupViewModel.swift` - Group management
- `ViewModels/GamesViewModel.swift` - Odds processing (updated)
- `ViewModels/BettingViewModel.swift` - Needs update for new bet types

### Views
- `Views/GroupSelectionView.swift` - First-time group flow
- `Views/CreateGroupView.swift` - Group creation
- `Views/RivalriesView.swift` - Head-to-head stats
- `Views/PlaceBetView.swift` - **Needs update** for spread/totals
- `Views/MainTabView.swift` - **Needs update** for new navigation

### Services
- `Services/OddsAPIService.swift` - Fetches spreads + totals (updated)

---

## ✨ Success Metrics

Track these to validate the refactor:

**Engagement:**
- Average bets per user per week (target: 3-5)
- Group retention week-over-week (target: >70%)
- Rivalry views per user (target: >2/week)

**Onboarding:**
- Newcomer completion rate (first bet placed) (target: >80%)
- Time to first bet (target: <2 minutes after joining group)

**User Satisfaction:**
- Can users explain what a spread bet is after placing one?
- Do users check rivalries without prompting?
- Do users feel it's a "game with friends" vs a casino?

---

## 🤝 Contributing

When continuing this refactor:

1. Follow existing code patterns in GroupViewModel and RivalriesView
2. Use TokenTossTheme for colors (gold/green/red/gray)
3. Add inline comments for complex database queries
4. Test with at least 3 users in a group for realistic rivalry data
5. Keep newcomer tooltips simple and friendly
6. Update this guide with any new discoveries or changes

---

**Last Updated:** December 2024
**Status:** Phase 1 ✅ Complete | Phase 2 ✅ API Complete, UI Pending | Phase 3-4 🚧 In Progress
