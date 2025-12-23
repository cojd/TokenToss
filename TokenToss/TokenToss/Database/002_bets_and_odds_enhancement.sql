-- Bets and Odds Enhancement for Friend-First Betting
-- Migration 002: Add group context and simplified bet types (spread + totals only)

-- ==================================================
-- UPDATE BETS TABLE
-- ==================================================

-- Add group_id column to bets table
ALTER TABLE bets ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE CASCADE;

-- Add index for group-scoped queries
CREATE INDEX IF NOT EXISTS idx_bets_group ON bets(group_id, user_id);
CREATE INDEX IF NOT EXISTS idx_bets_group_game ON bets(group_id, game_id);

-- Add new bet type fields for spread and totals
ALTER TABLE bets ADD COLUMN IF NOT EXISTS bet_detail JSONB;
-- bet_detail structure:
-- For spread bets: {"type": "spread", "team": "home|away", "line": -7.5, "odds": -110}
-- For total bets: {"type": "total", "selection": "over|under", "line": 45.5, "odds": -110}

COMMENT ON COLUMN bets.group_id IS 'Group context for this bet. All bets must belong to a group.';
COMMENT ON COLUMN bets.bet_detail IS 'Structured bet data for spread/total bets. JSONB for flexibility.';

-- ==================================================
-- UPDATE ODDS TABLE
-- ==================================================

-- Add spread and totals columns to odds table
ALTER TABLE odds ADD COLUMN IF NOT EXISTS home_spread DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS home_spread_odds INT;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS away_spread DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS away_spread_odds INT;

ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_over_line DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_over_odds INT;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_under_line DECIMAL;
ALTER TABLE odds ADD COLUMN IF NOT EXISTS total_under_odds INT;

-- Indexes for efficient odds lookups
CREATE INDEX IF NOT EXISTS idx_odds_game_time ON odds(game_id, captured_at DESC);

COMMENT ON COLUMN odds.home_spread IS 'Point spread for home team (e.g., -7.5)';
COMMENT ON COLUMN odds.away_spread IS 'Point spread for away team (e.g., +7.5)';
COMMENT ON COLUMN odds.total_over_line IS 'Over/under line (same for both over and under)';
COMMENT ON COLUMN odds.total_over_odds IS 'Odds for over bet (e.g., -110)';
COMMENT ON COLUMN odds.total_under_odds IS 'Odds for under bet (e.g., -110)';

-- ==================================================
-- UPDATED PLACE_BET FUNCTION (GROUP-AWARE)
-- ==================================================

CREATE OR REPLACE FUNCTION place_bet(
  p_user_id UUID,
  p_game_id UUID,
  p_group_id UUID,
  p_bet_type TEXT, -- 'spread' or 'total'
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
  -- Validate user is member of group
  SELECT EXISTS(
    SELECT 1 FROM group_members
    WHERE group_id = p_group_id
    AND user_id = p_user_id
    AND is_active = TRUE
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'User is not a member of this group'
    );
  END IF;

  -- Validate bet type
  IF p_bet_type NOT IN ('spread', 'total') THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'Invalid bet type. Only spread and total bets allowed.'
    );
  END IF;

  -- Get wallet info
  SELECT id, balance INTO v_wallet_id, v_current_balance
  FROM wallets
  WHERE user_id = p_user_id;

  -- Check sufficient balance
  IF v_current_balance < p_wager_amount THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'Insufficient balance',
      'current_balance', v_current_balance,
      'required', p_wager_amount
    );
  END IF;

  -- Extract odds and team from bet_detail
  v_odds := (p_bet_detail->>'odds')::INT;

  IF p_bet_type = 'spread' THEN
    v_team_bet_on := p_bet_detail->>'team';
  ELSIF p_bet_type = 'total' THEN
    v_team_bet_on := p_bet_detail->>'selection'; -- 'over' or 'under'
  END IF;

  -- Calculate potential payout
  IF v_odds > 0 THEN
    -- Positive odds: profit = (wager * odds) / 100
    v_potential_payout := p_wager_amount + (p_wager_amount * v_odds / 100);
  ELSE
    -- Negative odds: profit = (wager * 100) / abs(odds)
    v_potential_payout := p_wager_amount + (p_wager_amount * 100 / ABS(v_odds));
  END IF;

  -- Deduct wager from balance
  v_new_balance := v_current_balance - p_wager_amount;

  UPDATE wallets
  SET
    balance = v_new_balance,
    lifetime_spent = lifetime_spent + p_wager_amount,
    updated_at = NOW()
  WHERE id = v_wallet_id;

  -- Create transaction record
  INSERT INTO transactions (wallet_id, transaction_type, amount, balance_before, balance_after)
  VALUES (v_wallet_id, 'bet_placed', -p_wager_amount, v_current_balance, v_new_balance);

  -- Create bet record
  INSERT INTO bets (
    user_id,
    game_id,
    group_id,
    bet_type,
    team_bet_on,
    wager_amount,
    odds_at_bet,
    potential_payout,
    bet_status,
    bet_detail
  )
  VALUES (
    p_user_id,
    p_game_id,
    p_group_id,
    p_bet_type,
    v_team_bet_on,
    p_wager_amount,
    v_odds,
    v_potential_payout,
    'pending',
    p_bet_detail
  )
  RETURNING id INTO v_bet_id;

  -- Update transaction with bet_id
  UPDATE transactions
  SET bet_id = v_bet_id
  WHERE wallet_id = v_wallet_id
  AND bet_id IS NULL
  AND created_at = (
    SELECT MAX(created_at)
    FROM transactions
    WHERE wallet_id = v_wallet_id
  );

  RETURN json_build_object(
    'success', TRUE,
    'bet_id', v_bet_id,
    'new_balance', v_new_balance,
    'potential_payout', v_potential_payout
  );
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- SETTLE BET FUNCTION (GROUP-AWARE)
-- ==================================================

CREATE OR REPLACE FUNCTION settle_bet(
  p_bet_id UUID,
  p_won BOOLEAN
)
RETURNS JSON AS $$
DECLARE
  v_bet RECORD;
  v_wallet_id UUID;
  v_current_balance BIGINT;
  v_new_balance BIGINT;
  v_payout_amount BIGINT;
  v_transaction_type TEXT;
BEGIN
  -- Get bet details
  SELECT * INTO v_bet FROM bets WHERE id = p_bet_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet not found');
  END IF;

  IF v_bet.bet_status != 'pending' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Bet already settled');
  END IF;

  -- Get wallet
  SELECT id, balance INTO v_wallet_id, v_current_balance
  FROM wallets
  WHERE user_id = v_bet.user_id;

  -- Calculate payout
  IF p_won THEN
    v_payout_amount := v_bet.potential_payout;
    v_new_balance := v_current_balance + v_payout_amount;
    v_transaction_type := 'bet_won';

    UPDATE wallets
    SET
      balance = v_new_balance,
      lifetime_earned = lifetime_earned + (v_payout_amount - v_bet.wager_amount),
      updated_at = NOW()
    WHERE id = v_wallet_id;
  ELSE
    v_payout_amount := 0;
    v_new_balance := v_current_balance;
    v_transaction_type := 'bet_lost';
  END IF;

  -- Update bet status
  UPDATE bets
  SET
    bet_status = CASE WHEN p_won THEN 'won' ELSE 'lost' END,
    payout_amount = v_payout_amount,
    settled_at = NOW()
  WHERE id = p_bet_id;

  -- Create transaction if won
  IF p_won THEN
    INSERT INTO transactions (wallet_id, transaction_type, amount, balance_before, balance_after, bet_id)
    VALUES (v_wallet_id, v_transaction_type, v_payout_amount, v_current_balance, v_new_balance, p_bet_id);
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'bet_id', p_bet_id,
    'won', p_won,
    'payout_amount', v_payout_amount,
    'new_balance', v_new_balance
  );
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- SETTLE GAME FUNCTION (SETTLES ALL BETS FOR A GAME)
-- ==================================================

CREATE OR REPLACE FUNCTION settle_game(
  p_game_id UUID,
  p_home_score INT,
  p_away_score INT
)
RETURNS JSON AS $$
DECLARE
  v_bet RECORD;
  v_won BOOLEAN;
  v_bets_settled INT := 0;
  v_spread_line DECIMAL;
  v_total_line DECIMAL;
  v_total_score INT;
BEGIN
  -- Update game scores
  UPDATE nfl_games
  SET
    home_score = p_home_score,
    away_score = p_away_score,
    is_completed = TRUE,
    updated_at = NOW()
  WHERE id = p_game_id;

  -- Calculate total score for totals bets
  v_total_score := p_home_score + p_away_score;

  -- Loop through all pending bets for this game
  FOR v_bet IN
    SELECT * FROM bets
    WHERE game_id = p_game_id
    AND bet_status = 'pending'
  LOOP
    v_won := FALSE;

    -- Determine if bet won based on type
    IF v_bet.bet_type = 'spread' THEN
      v_spread_line := (v_bet.bet_detail->>'line')::DECIMAL;

      IF v_bet.team_bet_on = 'home' THEN
        -- Home team bet: home_score + spread > away_score
        IF p_home_score + v_spread_line > p_away_score THEN
          v_won := TRUE;
        END IF;
      ELSIF v_bet.team_bet_on = 'away' THEN
        -- Away team bet: away_score + spread > home_score
        IF p_away_score + ABS(v_spread_line) > p_home_score THEN
          v_won := TRUE;
        END IF;
      END IF;

    ELSIF v_bet.bet_type = 'total' THEN
      v_total_line := (v_bet.bet_detail->>'line')::DECIMAL;

      IF v_bet.team_bet_on = 'over' THEN
        IF v_total_score > v_total_line THEN
          v_won := TRUE;
        END IF;
      ELSIF v_bet.team_bet_on = 'under' THEN
        IF v_total_score < v_total_line THEN
          v_won := TRUE;
        END IF;
      END IF;
    END IF;

    -- Settle the bet
    PERFORM settle_bet(v_bet.id, v_won);
    v_bets_settled := v_bets_settled + 1;
  END LOOP;

  RETURN json_build_object(
    'success', TRUE,
    'game_id', p_game_id,
    'bets_settled', v_bets_settled,
    'home_score', p_home_score,
    'away_score', p_away_score
  );
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- VIEWS FOR GROUP BETTING
-- ==================================================

-- View: Group leaderboard by token balance
CREATE OR REPLACE VIEW group_leaderboard AS
SELECT
  gm.group_id,
  gm.user_id,
  p.username,
  gm.display_name,
  w.balance,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'won') as wins,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'lost') as losses,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'pending') as pending,
  COALESCE(SUM(b.wager_amount) FILTER (WHERE b.bet_status != 'cancelled'), 0) as total_wagered,
  COALESCE(SUM(b.payout_amount - b.wager_amount) FILTER (WHERE b.bet_status = 'won'), 0) as total_profit,
  CASE
    WHEN COUNT(b.id) FILTER (WHERE b.bet_status IN ('won', 'lost')) > 0
    THEN ROUND(
      100.0 * COUNT(b.id) FILTER (WHERE b.bet_status = 'won') /
      COUNT(b.id) FILTER (WHERE b.bet_status IN ('won', 'lost')),
      1
    )
    ELSE 0
  END as win_percentage
FROM group_members gm
JOIN profiles p ON gm.user_id = p.id
LEFT JOIN wallets w ON gm.user_id = w.user_id
LEFT JOIN bets b ON b.user_id = gm.user_id AND b.group_id = gm.group_id
WHERE gm.is_active = TRUE
GROUP BY gm.group_id, gm.user_id, p.username, gm.display_name, w.balance;

-- View: Group bets for a specific game (who bet what)
CREATE OR REPLACE VIEW group_game_bets AS
SELECT
  b.group_id,
  b.game_id,
  b.user_id,
  p.username,
  gm.display_name,
  b.bet_type,
  b.team_bet_on,
  b.wager_amount,
  b.odds_at_bet,
  b.bet_status,
  b.bet_detail,
  b.placed_at
FROM bets b
JOIN profiles p ON b.user_id = p.id
LEFT JOIN group_members gm ON gm.user_id = b.user_id AND gm.group_id = b.group_id
WHERE b.bet_status != 'cancelled'
ORDER BY b.placed_at DESC;

COMMENT ON VIEW group_leaderboard IS 'Group-scoped leaderboard with win/loss records and token balances.';
COMMENT ON VIEW group_game_bets IS 'Shows all bets for a game within a group (friend betting indicators).';
