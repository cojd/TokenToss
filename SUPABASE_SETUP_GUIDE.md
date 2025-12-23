# Supabase Setup Guide - Friend-First Betting Refactor

Complete step-by-step guide to set up your Supabase database for the friend-first betting app.

---

## 📋 Prerequisites

- Fresh Supabase project (or existing project - this guide works for both)
- Access to your Supabase dashboard
- SQL Editor access

---

## 🚀 Quick Start for New Projects

If you're starting from scratch, run **Migration 000** first to create base tables, then run migrations 001-004.

If you have existing tables, skip Migration 000 and go straight to Migration 001.

---

## Quick Start

### Step 1: Open Supabase SQL Editor

1. Go to https://supabase.com/dashboard
2. Select your TokenToss project
3. Click **SQL Editor** in the left sidebar
4. Click **+ New Query**

### Step 2: Run Migrations in Order

**⚠️ IMPORTANT:**
- **New projects:** Run Migration 000 first, then 001 → 002 → 003 → 004
- **Existing projects:** Skip 000, run 001 → 002 → 003 → 004

---

## Migration 000: Base Tables (New Projects Only)

**⚠️ Skip this if you already have profiles, wallets, bets, nfl_games, odds, and transactions tables**

**What this creates:**
- `profiles` table (user profiles)
- `wallets` table (token balances)
- `nfl_games` table (NFL game data)
- `bets` table (user bets)
- `odds` table (betting odds)
- `transactions` table (wallet transactions)
- `api_usage_log` table (API quota tracking)

**Copy this entire block and click RUN:**

```sql
-- Base Tables for TokenToss Betting App
-- Migration 000: Core infrastructure (for new projects)

-- ==================================================
-- PROFILES TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS Policies for profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all profiles" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- ==================================================
-- WALLETS TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS wallets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  balance BIGINT DEFAULT 1000 CHECK (balance >= 0),
  lifetime_earned BIGINT DEFAULT 0,
  lifetime_spent BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);

-- RLS Policies for wallets
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own wallet" ON wallets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own wallet" ON wallets
  FOR UPDATE USING (auth.uid() = user_id);

-- ==================================================
-- NFL GAMES TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS nfl_games (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  external_id TEXT UNIQUE NOT NULL,
  home_team TEXT NOT NULL,
  away_team TEXT NOT NULL,
  commence_time TIMESTAMPTZ NOT NULL,
  home_score INT,
  away_score INT,
  is_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_games_commence_time ON nfl_games(commence_time);
CREATE INDEX IF NOT EXISTS idx_games_external_id ON nfl_games(external_id);

-- RLS Policies for nfl_games
ALTER TABLE nfl_games ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view games" ON nfl_games
  FOR SELECT USING (true);

-- ==================================================
-- ODDS TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS odds (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID REFERENCES nfl_games(id) ON DELETE CASCADE NOT NULL,
  home_moneyline INT,
  away_moneyline INT,
  captured_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_odds_game_id ON odds(game_id);

-- RLS Policies for odds
ALTER TABLE odds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view odds" ON odds
  FOR SELECT USING (true);

-- ==================================================
-- BETS TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS bets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  game_id UUID REFERENCES nfl_games(id) ON DELETE CASCADE NOT NULL,
  bet_type TEXT NOT NULL,
  team_bet_on TEXT NOT NULL,
  wager_amount BIGINT NOT NULL CHECK (wager_amount > 0),
  odds_at_bet INT NOT NULL,
  potential_payout BIGINT NOT NULL,
  bet_status TEXT DEFAULT 'pending' CHECK (bet_status IN ('pending', 'won', 'lost', 'cancelled')),
  payout_amount BIGINT DEFAULT 0,
  placed_at TIMESTAMPTZ DEFAULT NOW(),
  settled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bets_user_id ON bets(user_id);
CREATE INDEX IF NOT EXISTS idx_bets_game_id ON bets(game_id);
CREATE INDEX IF NOT EXISTS idx_bets_status ON bets(bet_status);

-- RLS Policies for bets
ALTER TABLE bets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own bets" ON bets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own bets" ON bets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ==================================================
-- TRANSACTIONS TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE NOT NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('bet_placed', 'bet_won', 'bet_lost', 'allowance', 'adjustment')),
  amount BIGINT NOT NULL,
  balance_before BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  bet_id UUID REFERENCES bets(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_wallet_id ON transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_transactions_bet_id ON transactions(bet_id);

-- RLS Policies for transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own transactions" ON transactions
  FOR SELECT USING (
    wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid())
  );

-- ==================================================
-- API USAGE LOG TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS api_usage_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  endpoint TEXT NOT NULL,
  cost INTEGER NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_api_usage_timestamp ON api_usage_log(timestamp DESC);

-- ==================================================
-- TRIGGER: Auto-create wallet on user signup
-- ==================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'username', NEW.email));

  INSERT INTO public.wallets (user_id, balance)
  VALUES (NEW.id, 1000);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
```

**✅ Expected result:** "Success. No rows returned."

---

## Migration 001: Groups Schema

**What this creates:**
- `groups` table (betting groups)
- `group_members` table (membership)
- `group_invitations` table (invites)
- 5 functions for group operations
- 2 views for efficient queries

**Copy this entire block and click RUN:**

```sql
-- Groups and Group Membership Schema
-- Migration 001: Core group infrastructure

-- ==================================================
-- GROUPS TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Season and configuration
  season_year INT NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
  member_limit INT DEFAULT 15 CHECK (member_limit >= 2 AND member_limit <= 50),

  -- Group personality settings
  trash_talk_enabled BOOLEAN DEFAULT TRUE,
  weekly_token_allowance INT DEFAULT 500,
  allowance_day TEXT DEFAULT 'Sunday' CHECK (allowance_day IN ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')),
  group_image_url TEXT,

  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  description TEXT
);

CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by);
CREATE INDEX IF NOT EXISTS idx_groups_season ON groups(season_year);
CREATE INDEX IF NOT EXISTS idx_groups_active ON groups(is_active) WHERE is_active = TRUE;

-- ==================================================
-- GROUP MEMBERS TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS group_members (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  display_name TEXT,
  role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  is_active BOOLEAN DEFAULT TRUE,
  last_allowance_date DATE,
  allowance_received_this_week BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group_active ON group_members(group_id, is_active) WHERE is_active = TRUE;

-- ==================================================
-- GROUP INVITATIONS TABLE
-- ==================================================
CREATE TABLE IF NOT EXISTS group_invitations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  invited_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  UNIQUE(group_id, invited_user_id)
);

CREATE INDEX IF NOT EXISTS idx_invitations_invited_user ON group_invitations(invited_user_id, status);
CREATE INDEX IF NOT EXISTS idx_invitations_group ON group_invitations(group_id, status);

-- ==================================================
-- FUNCTIONS
-- ==================================================

CREATE OR REPLACE FUNCTION get_group_member_count(group_id_param UUID)
RETURNS INT AS $$
  SELECT COUNT(*)::INT
  FROM group_members
  WHERE group_id = group_id_param AND is_active = TRUE;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION can_join_group(group_id_param UUID, user_id_param UUID)
RETURNS BOOLEAN AS $$
DECLARE
  current_member_count INT;
  group_limit INT;
  is_already_member BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM group_members
    WHERE group_id = group_id_param AND user_id = user_id_param AND is_active = TRUE
  ) INTO is_already_member;

  IF is_already_member THEN RETURN FALSE; END IF;

  SELECT member_limit INTO group_limit FROM groups WHERE id = group_id_param;
  SELECT get_group_member_count(group_id_param) INTO current_member_count;

  RETURN current_member_count < group_limit;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION join_group(
  group_id_param UUID,
  user_id_param UUID,
  invitation_id_param UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  can_join BOOLEAN;
BEGIN
  SELECT can_join_group(group_id_param, user_id_param) INTO can_join;

  IF NOT can_join THEN
    RETURN json_build_object('success', FALSE, 'error', 'Cannot join group: already a member or group is full');
  END IF;

  INSERT INTO group_members (group_id, user_id) VALUES (group_id_param, user_id_param);

  IF invitation_id_param IS NOT NULL THEN
    UPDATE group_invitations SET status = 'accepted', responded_at = NOW() WHERE id = invitation_id_param;
  END IF;

  RETURN json_build_object('success', TRUE, 'group_id', group_id_param, 'user_id', user_id_param);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION leave_group(
  group_id_param UUID,
  user_id_param UUID
)
RETURNS JSON AS $$
DECLARE
  is_last_admin BOOLEAN;
BEGIN
  SELECT COUNT(*) = 1 INTO is_last_admin
  FROM group_members
  WHERE group_id = group_id_param AND role = 'admin' AND is_active = TRUE AND user_id = user_id_param;

  IF is_last_admin THEN
    RETURN json_build_object('success', FALSE, 'error', 'Cannot leave: you are the last admin.');
  END IF;

  UPDATE group_members SET is_active = FALSE WHERE group_id = group_id_param AND user_id = user_id_param;
  RETURN json_build_object('success', TRUE);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grant_weekly_allowance(group_id_param UUID)
RETURNS JSON AS $$
DECLARE
  allowance_amount INT;
  members_updated INT;
BEGIN
  SELECT weekly_token_allowance INTO allowance_amount FROM groups WHERE id = group_id_param;

  WITH updated_wallets AS (
    UPDATE wallets w
    SET balance = balance + allowance_amount
    FROM group_members gm
    WHERE w.user_id = gm.user_id
      AND gm.group_id = group_id_param
      AND gm.is_active = TRUE
      AND (gm.allowance_received_this_week = FALSE OR gm.last_allowance_date < CURRENT_DATE - INTERVAL '7 days')
    RETURNING w.user_id
  )
  SELECT COUNT(*) INTO members_updated FROM updated_wallets;

  UPDATE group_members
  SET allowance_received_this_week = TRUE, last_allowance_date = CURRENT_DATE
  WHERE group_id = group_id_param AND is_active = TRUE;

  RETURN json_build_object('success', TRUE, 'members_updated', members_updated, 'allowance_amount', allowance_amount);
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- VIEWS
-- ==================================================

CREATE OR REPLACE VIEW group_members_detailed AS
SELECT
  gm.group_id, gm.user_id, gm.joined_at, gm.display_name, gm.role, gm.is_active,
  p.username,
  w.balance as tokens,
  (SELECT COUNT(*) FROM bets b WHERE b.user_id = gm.user_id AND b.group_id = gm.group_id) as total_bets,
  (SELECT COUNT(*) FROM bets b WHERE b.user_id = gm.user_id AND b.group_id = gm.group_id AND b.bet_status = 'won') as bets_won,
  (SELECT COUNT(*) FROM bets b WHERE b.user_id = gm.user_id AND b.group_id = gm.group_id AND b.bet_status = 'lost') as bets_lost
FROM group_members gm
JOIN profiles p ON gm.user_id = p.id
LEFT JOIN wallets w ON gm.user_id = w.user_id
WHERE gm.is_active = TRUE;

CREATE OR REPLACE VIEW groups_summary AS
SELECT g.*, get_group_member_count(g.id) as member_count, p.username as creator_username
FROM groups g
LEFT JOIN profiles p ON g.created_by = p.id
WHERE g.is_active = TRUE;
```

**✅ Expected result:** "Success. No rows returned."

---

## Migration 002: Bets & Odds Enhancement

**What this does:**
- Adds `group_id` column to `bets` table
- Adds `bet_detail` JSONB column for spread/total data
- Adds spread and totals columns to `odds` table
- Updates `place_bet()` function for group-scoped betting
- Creates bet settlement functions

**Copy this entire block and click RUN:**

```sql
-- Bets and Odds Enhancement
-- Migration 002: Group context and simplified bet types

-- ==================================================
-- UPDATE BETS TABLE
-- ==================================================

ALTER TABLE bets ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE CASCADE;
ALTER TABLE bets ADD COLUMN IF NOT EXISTS bet_detail JSONB;

CREATE INDEX IF NOT EXISTS idx_bets_group ON bets(group_id, user_id);
CREATE INDEX IF NOT EXISTS idx_bets_group_game ON bets(group_id, game_id);

-- ==================================================
-- UPDATE ODDS TABLE
-- ==================================================

ALTER TABLE odds ADD COLUMN IF NOT EXISTS home_spread DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS home_spread_odds INT;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS away_spread DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS away_spread_odds INT;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_over_line DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_over_odds INT;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_under_line DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_under_odds INT;

CREATE INDEX IF NOT EXISTS idx_odds_game_time ON odds(game_id, captured_at DESC);

-- ==================================================
-- PLACE BET FUNCTION (GROUP-AWARE)
-- ==================================================

CREATE OR REPLACE FUNCTION place_bet(
  p_user_id UUID,
  p_game_id UUID,
  p_group_id UUID,
  p_bet_type TEXT,
  p_bet_detail JSONB,
  p_wager_amount BIGINT
)
RETURNS JSON AS $$
DECLARE
  v_wallet_id UUID;
  v_current_balance BIGINT;
  v_new_balance BIGINT;
  v_potential_payout BIGINT;
  v_bet_id UUID;
  v_odds INT;
  v_team_bet_on TEXT;
  v_is_member BOOLEAN;
BEGIN
  -- Validate group membership
  SELECT EXISTS(
    SELECT 1 FROM group_members
    WHERE group_id = p_group_id AND user_id = p_user_id AND is_active = TRUE
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN json_build_object('success', FALSE, 'error', 'User is not a member of this group');
  END IF;

  -- Validate bet type
  IF p_bet_type NOT IN ('spread', 'total') THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid bet type. Only spread and total bets allowed.');
  END IF;

  -- Get wallet
  SELECT id, balance INTO v_wallet_id, v_current_balance FROM wallets WHERE user_id = p_user_id;

  IF v_current_balance < p_wager_amount THEN
    RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
  END IF;

  -- Extract odds and team
  v_odds := (p_bet_detail->>'odds')::INT;
  v_team_bet_on := COALESCE(p_bet_detail->>'team', p_bet_detail->>'selection');

  -- Calculate payout
  IF v_odds > 0 THEN
    v_potential_payout := p_wager_amount + (p_wager_amount * v_odds / 100);
  ELSE
    v_potential_payout := p_wager_amount + (p_wager_amount * 100 / ABS(v_odds));
  END IF;

  -- Deduct wager
  v_new_balance := v_current_balance - p_wager_amount;
  UPDATE wallets SET balance = v_new_balance, lifetime_spent = lifetime_spent + p_wager_amount, updated_at = NOW()
  WHERE id = v_wallet_id;

  -- Create transaction
  INSERT INTO transactions (wallet_id, transaction_type, amount, balance_before, balance_after)
  VALUES (v_wallet_id, 'bet_placed', -p_wager_amount, v_current_balance, v_new_balance);

  -- Create bet
  INSERT INTO bets (user_id, game_id, group_id, bet_type, team_bet_on, wager_amount, odds_at_bet, potential_payout, bet_status, bet_detail)
  VALUES (p_user_id, p_game_id, p_group_id, p_bet_type, v_team_bet_on, p_wager_amount, v_odds, v_potential_payout, 'pending', p_bet_detail)
  RETURNING id INTO v_bet_id;

  RETURN json_build_object('success', TRUE, 'bet_id', v_bet_id, 'new_balance', v_new_balance, 'potential_payout', v_potential_payout);
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- SETTLE BET FUNCTION
-- ==================================================

CREATE OR REPLACE FUNCTION settle_bet(p_bet_id UUID, p_won BOOLEAN)
RETURNS JSON AS $$
DECLARE
  v_bet RECORD;
  v_wallet_id UUID;
  v_current_balance BIGINT;
  v_new_balance BIGINT;
  v_payout_amount BIGINT;
BEGIN
  SELECT * INTO v_bet FROM bets WHERE id = p_bet_id;
  IF NOT FOUND THEN RETURN json_build_object('success', FALSE, 'error', 'Bet not found'); END IF;
  IF v_bet.bet_status != 'pending' THEN RETURN json_build_object('success', FALSE, 'error', 'Bet already settled'); END IF;

  SELECT id, balance INTO v_wallet_id, v_current_balance FROM wallets WHERE user_id = v_bet.user_id;

  IF p_won THEN
    v_payout_amount := v_bet.potential_payout;
    v_new_balance := v_current_balance + v_payout_amount;
    UPDATE wallets SET balance = v_new_balance, lifetime_earned = lifetime_earned + (v_payout_amount - v_bet.wager_amount), updated_at = NOW()
    WHERE id = v_wallet_id;
    INSERT INTO transactions (wallet_id, transaction_type, amount, balance_before, balance_after, bet_id)
    VALUES (v_wallet_id, 'bet_won', v_payout_amount, v_current_balance, v_new_balance, p_bet_id);
  ELSE
    v_payout_amount := 0;
    v_new_balance := v_current_balance;
  END IF;

  UPDATE bets SET bet_status = CASE WHEN p_won THEN 'won' ELSE 'lost' END, payout_amount = v_payout_amount, settled_at = NOW()
  WHERE id = p_bet_id;

  RETURN json_build_object('success', TRUE, 'won', p_won, 'payout_amount', v_payout_amount, 'new_balance', v_new_balance);
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- VIEWS
-- ==================================================

CREATE OR REPLACE VIEW group_leaderboard AS
SELECT
  gm.group_id, gm.user_id, p.username, gm.display_name, w.balance,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'won') as wins,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'lost') as losses,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'pending') as pending,
  COALESCE(SUM(b.wager_amount) FILTER (WHERE b.bet_status != 'cancelled'), 0) as total_wagered,
  COALESCE(SUM(b.payout_amount - b.wager_amount) FILTER (WHERE b.bet_status = 'won'), 0) as total_profit,
  CASE WHEN COUNT(b.id) FILTER (WHERE b.bet_status IN ('won', 'lost')) > 0
    THEN ROUND(100.0 * COUNT(b.id) FILTER (WHERE b.bet_status = 'won') / COUNT(b.id) FILTER (WHERE b.bet_status IN ('won', 'lost')), 1)
    ELSE 0 END as win_percentage
FROM group_members gm
JOIN profiles p ON gm.user_id = p.id
LEFT JOIN wallets w ON gm.user_id = w.user_id
LEFT JOIN bets b ON b.user_id = gm.user_id AND b.group_id = gm.group_id
WHERE gm.is_active = TRUE
GROUP BY gm.group_id, gm.user_id, p.username, gm.display_name, w.balance;
```

**✅ Expected result:** "Success. No rows returned."

---

## Migration 003: Profiles Enhancement

**What this does:**
- Adds betting experience tracking to profiles
- Adds onboarding flags
- Creates auto-trigger to update experience levels
- Adds newcomer detection functions

**Copy this entire block and click RUN:**

```sql
-- Profiles Enhancement
-- Migration 003: Newcomer onboarding and experience tracking

-- ==================================================
-- UPDATE PROFILES TABLE
-- ==================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS betting_experience TEXT DEFAULT 'newcomer'
  CHECK (betting_experience IN ('newcomer', 'intermediate', 'experienced'));
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_bets_placed INT DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS first_bet_date TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{}';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profile_image_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_experience ON profiles(betting_experience);

-- ==================================================
-- UPDATE USER EXPERIENCE LEVEL
-- ==================================================

CREATE OR REPLACE FUNCTION update_user_experience_level(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_total_bets INT;
  v_new_experience TEXT;
BEGIN
  SELECT COUNT(*) INTO v_total_bets FROM bets WHERE user_id = p_user_id AND bet_status != 'cancelled';

  IF v_total_bets < 10 THEN v_new_experience := 'newcomer';
  ELSIF v_total_bets < 50 THEN v_new_experience := 'intermediate';
  ELSE v_new_experience := 'experienced';
  END IF;

  UPDATE profiles SET total_bets_placed = v_total_bets, betting_experience = v_new_experience, updated_at = NOW()
  WHERE id = p_user_id;

  IF v_total_bets = 1 THEN
    UPDATE profiles SET first_bet_date = NOW() WHERE id = p_user_id;
  END IF;

  RETURN v_new_experience;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- AUTO-TRIGGER ON BET PLACEMENT
-- ==================================================

CREATE OR REPLACE FUNCTION trigger_update_experience_on_bet()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.bet_status != 'cancelled' THEN
    PERFORM update_user_experience_level(NEW.user_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_experience_on_bet_insert ON bets;
CREATE TRIGGER update_experience_on_bet_insert
AFTER INSERT ON bets
FOR EACH ROW
EXECUTE FUNCTION trigger_update_experience_on_bet();

-- ==================================================
-- INITIALIZE EXISTING USERS
-- ==================================================

DO $$
DECLARE user_record RECORD;
BEGIN
  FOR user_record IN SELECT id FROM profiles LOOP
    PERFORM update_user_experience_level(user_record.id);
  END LOOP;
END $$;
```

**✅ Expected result:** "Success. No rows returned."

---

## Migration 004: Rivalry Stats

**What this creates:**
- Head-to-head rivalry tracking functions
- Game betting breakdown
- Post-game results with rivalry comparison

**Copy this entire block and click RUN:**

```sql
-- Rivalry Stats
-- Migration 004: Head-to-head competition tracking

-- ==================================================
-- GET RIVALRY STATS (1v1)
-- ==================================================

CREATE OR REPLACE FUNCTION get_rivalry_stats(
  p_group_id UUID,
  p_user1_id UUID,
  p_user2_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
  v_user1_name TEXT;
  v_user2_name TEXT;
BEGIN
  SELECT username INTO v_user1_name FROM profiles WHERE id = p_user1_id;
  SELECT username INTO v_user2_name FROM profiles WHERE id = p_user2_id;

  WITH matchups AS (
    SELECT
      b1.game_id, b1.team_bet_on as user1_pick, b2.team_bet_on as user2_pick,
      b1.bet_status as user1_result, b2.bet_status as user2_result,
      (b1.payout_amount - b1.wager_amount) as user1_profit,
      (b2.payout_amount - b2.wager_amount) as user2_profit,
      g.home_team, g.away_team, g.commence_time
    FROM bets b1
    JOIN bets b2 ON b1.game_id = b2.game_id AND b1.group_id = b2.group_id AND b1.user_id != b2.user_id
    JOIN nfl_games g ON b1.game_id = g.id
    WHERE b1.group_id = p_group_id
      AND b1.user_id = p_user1_id
      AND b2.user_id = p_user2_id
      AND b1.bet_status IN ('won', 'lost')
      AND b2.bet_status IN ('won', 'lost')
  )
  SELECT json_build_object(
    'user1', json_build_object('id', p_user1_id, 'username', v_user1_name),
    'user2', json_build_object('id', p_user2_id, 'username', v_user2_name),
    'stats', json_build_object(
      'total_matchups', COUNT(*),
      'user1_wins', COUNT(*) FILTER (WHERE user1_result = 'won' AND user2_result = 'lost'),
      'user2_wins', COUNT(*) FILTER (WHERE user2_result = 'won' AND user1_result = 'lost'),
      'both_won', COUNT(*) FILTER (WHERE user1_result = 'won' AND user2_result = 'won'),
      'both_lost', COUNT(*) FILTER (WHERE user1_result = 'lost' AND user2_result = 'lost'),
      'user1_total_profit', COALESCE(SUM(user1_profit), 0),
      'user2_total_profit', COALESCE(SUM(user2_profit), 0),
      'opposite_picks_count', COUNT(*) FILTER (WHERE user1_pick != user2_pick)
    ),
    'recent_matchups', (
      SELECT json_agg(json_build_object(
        'game_id', game_id, 'home_team', home_team, 'away_team', away_team,
        'user1_pick', user1_pick, 'user2_pick', user2_pick,
        'user1_result', user1_result, 'user2_result', user2_result
      ) ORDER BY commence_time DESC)
      FROM (SELECT * FROM matchups ORDER BY commence_time DESC LIMIT 5) recent
    )
  ) INTO v_result FROM matchups;

  RETURN COALESCE(v_result, json_build_object(
    'user1', json_build_object('id', p_user1_id, 'username', v_user1_name),
    'user2', json_build_object('id', p_user2_id, 'username', v_user2_name),
    'stats', json_build_object('total_matchups', 0)
  ));
END;
$$ LANGUAGE plpgsql STABLE;

-- ==================================================
-- GET ALL RIVALRIES FOR USER
-- ==================================================

CREATE OR REPLACE FUNCTION get_user_rivalries(
  p_group_id UUID,
  p_user_id UUID
)
RETURNS JSON AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'rival_id', rival_id,
        'rival_username', rival_username,
        'matchups', matchups,
        'wins', wins,
        'losses', losses,
        'ties', ties,
        'win_rate', CASE WHEN matchups > 0 THEN ROUND(100.0 * wins / matchups, 1) ELSE 0 END,
        'profit_diff', profit_diff
      ) ORDER BY matchups DESC, wins DESC
    )
    FROM (
      SELECT
        gm.user_id as rival_id,
        p.username as rival_username,
        COUNT(DISTINCT b1.game_id) as matchups,
        COUNT(*) FILTER (WHERE b1.bet_status = 'won' AND b2.bet_status = 'lost') as wins,
        COUNT(*) FILTER (WHERE b1.bet_status = 'lost' AND b2.bet_status = 'won') as losses,
        COUNT(*) FILTER (WHERE b1.bet_status = b2.bet_status) as ties,
        COALESCE(SUM((b1.payout_amount - b1.wager_amount) - (b2.payout_amount - b2.wager_amount)), 0) as profit_diff
      FROM group_members gm
      JOIN profiles p ON gm.user_id = p.id
      LEFT JOIN bets b1 ON b1.user_id = p_user_id AND b1.group_id = p_group_id
      LEFT JOIN bets b2 ON b2.user_id = gm.user_id AND b2.game_id = b1.game_id AND b2.group_id = b1.group_id
      WHERE gm.group_id = p_group_id AND gm.user_id != p_user_id AND gm.is_active = TRUE
      GROUP BY gm.user_id, p.username
    ) rivalry_summary
  );
END;
$$ LANGUAGE plpgsql STABLE;
```

**✅ Expected result:** "Success. No rows returned."

---

## ✅ Verification Steps

After running all migrations, verify everything is set up:

### 1. Check Base Tables Exist (if you ran Migration 000)

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('profiles', 'wallets', 'nfl_games', 'bets', 'odds', 'transactions', 'api_usage_log')
ORDER BY table_name;
```

**Expected:** 7 rows

### 2. Check Group Tables Exist

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('groups', 'group_members', 'group_invitations')
ORDER BY table_name;
```

**Expected:** 3 rows (groups, group_invitations, group_members)

### 3. Check Functions Exist

```sql
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%group%' OR routine_name LIKE '%rivalry%'
ORDER BY routine_name;
```

**Expected:** At least 8 functions

### 4. Check Views Exist

```sql
SELECT table_name FROM information_schema.views
WHERE table_schema = 'public'
AND table_name LIKE '%group%'
ORDER BY table_name;
```

**Expected:** 3 views (group_leaderboard, group_members_detailed, groups_summary)

### 5. Test User Creation (New Projects Only)

If you haven't created any users yet, you can test the trigger:

```sql
-- Check if any users exist
SELECT count(*) FROM auth.users;

-- If 0 users, create one from your app's sign-up page first
-- Then verify the profile and wallet were auto-created:
SELECT p.id, p.username, w.balance
FROM profiles p
JOIN wallets w ON p.id = w.user_id
LIMIT 1;
```

**Expected:** Shows user with 1000 token starting balance

### 6. Test Group Creation

After you have at least one user:

```sql
-- Get a user ID to use for testing
SELECT id, username FROM profiles LIMIT 1;

-- Use that ID in the INSERT below (replace the UUID)
INSERT INTO groups (name, created_by, description)
VALUES (
  'Test Group',
  'PASTE_USER_ID_HERE',  -- Replace with actual UUID from above
  'Testing group creation'
)
RETURNING id, name, member_limit, weekly_token_allowance;
```

**Expected:** Returns new group details with default settings (15 member limit, 500 weekly allowance)

---

## 🎯 Next Steps

After successful migration:

1. **Test in your app:**
   - Try creating a group from GroupSelectionView
   - Invite another user
   - Place a bet (will need to update PlaceBetView for spread/totals)

2. **Check data:**
   ```sql
   SELECT * FROM groups_summary;
   SELECT * FROM group_members_detailed;
   ```

3. **Monitor API usage:**
   ```sql
   SELECT * FROM api_usage_log ORDER BY timestamp DESC LIMIT 10;
   ```

---

## 🆘 Troubleshooting

### Error: "relation 'profiles' does not exist"
**Fix:** Make sure your existing tables exist first. These migrations extend existing tables.

### Error: "column 'group_id' already exists"
**Fix:** Safe to ignore - `IF NOT EXISTS` clauses handle this.

### Error: "function already exists"
**Fix:** Safe to ignore - `CREATE OR REPLACE` handles this.

### Need to reset and start over?

```sql
-- ⚠️ WARNING: This deletes ALL group data
DROP TABLE IF EXISTS group_invitations CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP FUNCTION IF EXISTS get_group_member_count CASCADE;
DROP FUNCTION IF EXISTS can_join_group CASCADE;
DROP FUNCTION IF EXISTS join_group CASCADE;
DROP FUNCTION IF EXISTS leave_group CASCADE;
DROP FUNCTION IF EXISTS grant_weekly_allowance CASCADE;
DROP FUNCTION IF EXISTS get_rivalry_stats CASCADE;
DROP FUNCTION IF EXISTS get_user_rivalries CASCADE;
DROP VIEW IF EXISTS group_leaderboard CASCADE;
DROP VIEW IF EXISTS group_members_detailed CASCADE;
DROP VIEW IF EXISTS groups_summary CASCADE;

-- Then re-run all 4 migrations
```

---

## 📚 Additional Resources

- Full implementation guide: `FRIEND_FIRST_IMPLEMENTATION_GUIDE.md`
- Database documentation: `TokenToss/TokenToss/Database/README.md`
- SQL migration files: `TokenToss/TokenToss/Database/*.sql`

---

**Questions?** Check the implementation guide or the database README for detailed explanations of each table, function, and view.
