# Database Migrations - Friend-First Betting Refactor

This directory contains SQL migration files for the TokenToss friend-first betting refactor.

## Migration Files

### 001_groups_schema.sql
**Purpose:** Core group infrastructure for friend-first betting

**Tables Created:**
- `groups` - Betting groups with configuration (member limit, weekly allowance, etc.)
- `group_members` - Group membership with roles (admin/member)
- `group_invitations` - Group invitation system with expiration

**Functions:**
- `get_group_member_count()` - Returns active member count
- `can_join_group()` - Validates if user can join a group
- `join_group()` - Add user to group (with optional invitation)
- `leave_group()` - Remove user from group (soft delete)
- `grant_weekly_allowance()` - Grant weekly tokens to all group members

**Views:**
- `group_members_detailed` - Member info with betting stats
- `groups_summary` - Group info with member count

### 002_bets_and_odds_enhancement.sql
**Purpose:** Add group context and simplified bet types (spread + totals)

**Schema Changes:**
- `bets` table: Added `group_id` and `bet_detail` (JSONB) columns
- `odds` table: Added spread and totals columns

**Functions:**
- `place_bet()` - Updated to require group_id and support spread/total bets
- `settle_bet()` - Settle individual bet
- `settle_game()` - Settle all bets for a completed game

**Views:**
- `group_leaderboard` - Group-scoped leaderboard with stats
- `group_game_bets` - Shows who bet what on each game

### 003_profiles_enhancement.sql
**Purpose:** Newcomer onboarding and betting experience tracking

**Schema Changes:**
- `profiles` table: Added betting experience, onboarding flags, and preferences

**Functions:**
- `update_user_experience_level()` - Auto-update experience based on bet count
- `should_show_betting_tips()` - Determine if user should see tips
- `get_onboarding_status()` - Get complete onboarding progress

**Triggers:**
- Auto-update experience level when new bets are placed

**Views:**
- `user_profiles_with_stats` - User profiles enriched with betting stats

### 004_rivalry_stats.sql
**Purpose:** Head-to-head rivalry tracking for friend competition

**Functions:**
- `get_rivalry_stats()` - Comprehensive 1v1 stats between two users
- `get_user_rivalries()` - Get all rivalries for a user in a group
- `get_game_betting_breakdown()` - Shows who bet on each side of a game
- `get_post_game_results()` - Post-game results with rivalry comparison

**Views:**
- `rivalry_dominance` - Leaderboard showing who dominates their rivals

## Running Migrations

Execute migrations in order using Supabase SQL Editor or psql:

```sql
-- Run each migration file in order
\i 001_groups_schema.sql
\i 002_bets_and_odds_enhancement.sql
\i 003_profiles_enhancement.sql
\i 004_rivalry_stats.sql
```

## Key Design Decisions

### 1. One Group Per User (Initially)
- Users can only be in one group at a time
- Simplifies UX and token economy
- Can be expanded to multi-group in future

### 2. Group-Scoped Everything
- All bets must have a `group_id`
- Leaderboards are group-specific
- Rivalries are tracked within groups

### 3. Soft Deletes for Group Members
- Members are marked `is_active = FALSE` instead of deleted
- Preserves bet history and stats
- Allows for re-joining groups

### 4. Weekly Token Allowance
- Groups configure weekly token grant
- Distributed on configured day (default: Sunday)
- Prevents users from running out of tokens

### 5. Betting Experience Levels
- `newcomer`: < 10 bets (show tips and guides)
- `intermediate`: 10-50 bets
- `experienced`: 50+ bets
- Auto-updated via trigger on bet placement

### 6. JSONB for Bet Details
- `bet_detail` column stores structured bet data
- Flexible for different bet types (spread, total)
- Easy to extend for future bet types

### 7. Rivalry Tracking
- Tracks every matchup where users bet on the same game
- Differentiates between opposite picks vs same picks
- Stores profit differential for competitiveness

## Schema Compatibility

### Backward Compatibility
- Existing `bets` without `group_id` will need migration
- Suggested approach: Create "Legacy" groups for existing users
- New columns have default values or are nullable

### Migration Script for Existing Data
```sql
-- Create legacy groups for existing users
INSERT INTO groups (name, created_by, season_year)
SELECT CONCAT(u.email, ' - Legacy'), u.id, 2024
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM group_members gm WHERE gm.user_id = u.id
);

-- Assign users to their legacy groups
INSERT INTO group_members (group_id, user_id, role)
SELECT g.id, g.created_by, 'admin'
FROM groups g
WHERE g.name LIKE '% - Legacy';

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

## Testing

See `/Database/TESTING.md` for testing procedures.

## Performance Considerations

### Indexes
- All foreign keys are indexed
- Composite indexes on frequently queried columns
- Partial indexes on active records (`WHERE is_active = TRUE`)

### Query Optimization
- Views use CTEs and window functions efficiently
- RPC functions use proper WHERE clauses
- Group queries are limited to active members only

## Future Enhancements

### Potential V2 Features
- [ ] Multi-group support per user
- [ ] Group chat/messaging
- [ ] Group challenges and tournaments
- [ ] Custom group rules (bet limits, allowed bet types)
- [ ] Group achievements and badges
- [ ] Commissioner tools (kick members, edit settings)
- [ ] Group archives (season history)

## Support

For questions or issues with migrations:
1. Check Supabase logs for error details
2. Verify all prerequisite tables exist
3. Ensure user has appropriate database permissions
4. Review foreign key constraints
