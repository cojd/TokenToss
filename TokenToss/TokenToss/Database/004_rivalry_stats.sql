-- Rivalry Stats for Friend-First Competition
-- Migration 004: Head-to-head rivalry tracking and matchup statistics

-- ==================================================
-- FUNCTION: GET RIVALRY STATS BETWEEN TWO USERS
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
  -- Get usernames
  SELECT username INTO v_user1_name FROM profiles WHERE id = p_user1_id;
  SELECT username INTO v_user2_name FROM profiles WHERE id = p_user2_id;

  -- Calculate rivalry stats
  WITH matchups AS (
    SELECT
      b1.game_id,
      b1.user_id as user1_id,
      b2.user_id as user2_id,
      b1.bet_status as user1_result,
      b2.bet_status as user2_result,
      b1.team_bet_on as user1_pick,
      b2.team_bet_on as user2_pick,
      b1.wager_amount as user1_wager,
      b2.wager_amount as user2_wager,
      (b1.payout_amount - b1.wager_amount) as user1_profit,
      (b2.payout_amount - b2.wager_amount) as user2_profit,
      b1.placed_at,
      g.home_team,
      g.away_team,
      g.commence_time
    FROM bets b1
    JOIN bets b2
      ON b1.game_id = b2.game_id
      AND b1.group_id = b2.group_id
      AND b1.user_id != b2.user_id
    JOIN nfl_games g ON b1.game_id = g.id
    WHERE b1.group_id = p_group_id
      AND b1.user_id = p_user1_id
      AND b2.user_id = p_user2_id
      AND b1.bet_status IN ('won', 'lost')
      AND b2.bet_status IN ('won', 'lost')
  )
  SELECT json_build_object(
    'user1', json_build_object(
      'id', p_user1_id,
      'username', v_user1_name
    ),
    'user2', json_build_object(
      'id', p_user2_id,
      'username', v_user2_name
    ),
    'stats', json_build_object(
      'total_matchups', COUNT(*),
      'user1_wins', COUNT(*) FILTER (WHERE user1_result = 'won' AND user2_result = 'lost'),
      'user2_wins', COUNT(*) FILTER (WHERE user2_result = 'won' AND user1_result = 'lost'),
      'both_won', COUNT(*) FILTER (WHERE user1_result = 'won' AND user2_result = 'won'),
      'both_lost', COUNT(*) FILTER (WHERE user1_result = 'lost' AND user2_result = 'lost'),
      'user1_total_profit', COALESCE(SUM(user1_profit), 0),
      'user2_total_profit', COALESCE(SUM(user2_profit), 0),
      'biggest_user1_win', COALESCE(MAX(user1_profit) FILTER (WHERE user1_result = 'won'), 0),
      'biggest_user2_win', COALESCE(MAX(user2_profit) FILTER (WHERE user2_result = 'won'), 0),
      'last_matchup_date', MAX(commence_time),
      'opposite_picks_count', COUNT(*) FILTER (WHERE user1_pick != user2_pick)
    ),
    'recent_matchups', (
      SELECT json_agg(
        json_build_object(
          'game_id', game_id,
          'home_team', home_team,
          'away_team', away_team,
          'commence_time', commence_time,
          'user1_pick', user1_pick,
          'user2_pick', user2_pick,
          'user1_result', user1_result,
          'user2_result', user2_result,
          'user1_profit', user1_profit,
          'user2_profit', user2_profit
        )
        ORDER BY commence_time DESC
      )
      FROM (
        SELECT * FROM matchups
        ORDER BY commence_time DESC
        LIMIT 5
      ) recent
    )
  ) INTO v_result
  FROM matchups;

  RETURN COALESCE(v_result, json_build_object(
    'user1', json_build_object('id', p_user1_id, 'username', v_user1_name),
    'user2', json_build_object('id', p_user2_id, 'username', v_user2_name),
    'stats', json_build_object(
      'total_matchups', 0,
      'user1_wins', 0,
      'user2_wins', 0,
      'both_won', 0,
      'both_lost', 0,
      'user1_total_profit', 0,
      'user2_total_profit', 0,
      'biggest_user1_win', 0,
      'biggest_user2_win', 0,
      'last_matchup_date', NULL,
      'opposite_picks_count', 0
    ),
    'recent_matchups', '[]'::json
  ));
END;
$$ LANGUAGE plpgsql STABLE;

-- ==================================================
-- FUNCTION: GET ALL RIVALRIES FOR A USER
-- ==================================================

CREATE OR REPLACE FUNCTION get_user_rivalries(
  p_group_id UUID,
  p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_rival RECORD;
  v_rivalries JSON;
BEGIN
  SELECT json_agg(
    json_build_object(
      'rival_id', rival_id,
      'rival_username', rival_username,
      'matchups', matchups,
      'wins', wins,
      'losses', losses,
      'ties', ties,
      'win_rate', CASE WHEN matchups > 0 THEN ROUND(100.0 * wins / matchups, 1) ELSE 0 END,
      'profit_diff', profit_diff,
      'last_matchup', last_matchup
    )
    ORDER BY matchups DESC, wins DESC
  ) INTO v_rivalries
  FROM (
    SELECT
      gm.user_id as rival_id,
      p.username as rival_username,
      COUNT(DISTINCT b1.game_id) as matchups,
      COUNT(*) FILTER (
        WHERE b1.bet_status = 'won' AND b2.bet_status = 'lost'
      ) as wins,
      COUNT(*) FILTER (
        WHERE b1.bet_status = 'lost' AND b2.bet_status = 'won'
      ) as losses,
      COUNT(*) FILTER (
        WHERE b1.bet_status = b2.bet_status
      ) as ties,
      COALESCE(SUM(b1.payout_amount - b1.wager_amount) - SUM(b2.payout_amount - b2.wager_amount), 0) as profit_diff,
      MAX(g.commence_time) as last_matchup
    FROM group_members gm
    JOIN profiles p ON gm.user_id = p.id
    LEFT JOIN bets b1 ON b1.user_id = p_user_id AND b1.group_id = p_group_id
    LEFT JOIN bets b2 ON b2.user_id = gm.user_id
      AND b2.game_id = b1.game_id
      AND b2.group_id = b1.group_id
    LEFT JOIN nfl_games g ON b1.game_id = g.id
    WHERE gm.group_id = p_group_id
      AND gm.user_id != p_user_id
      AND gm.is_active = TRUE
    GROUP BY gm.user_id, p.username
  ) rivalry_summary;

  RETURN COALESCE(v_rivalries, '[]'::json);
END;
$$ LANGUAGE plpgsql STABLE;

-- ==================================================
-- FUNCTION: GET GAME BETTING BREAKDOWN (WHO BET WHAT)
-- ==================================================

CREATE OR REPLACE FUNCTION get_game_betting_breakdown(
  p_group_id UUID,
  p_game_id UUID
)
RETURNS JSON AS $$
BEGIN
  RETURN json_build_object(
    'game_id', p_game_id,
    'total_bettors', (
      SELECT COUNT(DISTINCT user_id)
      FROM bets
      WHERE group_id = p_group_id AND game_id = p_game_id
    ),
    'bets_by_type', (
      SELECT json_object_agg(bet_type, bet_count)
      FROM (
        SELECT bet_type, COUNT(*) as bet_count
        FROM bets
        WHERE group_id = p_group_id AND game_id = p_game_id
        GROUP BY bet_type
      ) type_counts
    ),
    'spread_bets', (
      SELECT json_build_object(
        'home', json_agg(
          json_build_object(
            'user_id', b.user_id,
            'username', p.username,
            'display_name', gm.display_name,
            'wager', b.wager_amount,
            'odds', b.odds_at_bet,
            'status', b.bet_status
          )
        ) FILTER (WHERE b.team_bet_on = 'home'),
        'away', json_agg(
          json_build_object(
            'user_id', b.user_id,
            'username', p.username,
            'display_name', gm.display_name,
            'wager', b.wager_amount,
            'odds', b.odds_at_bet,
            'status', b.bet_status
          )
        ) FILTER (WHERE b.team_bet_on = 'away')
      )
      FROM bets b
      JOIN profiles p ON b.user_id = p.id
      LEFT JOIN group_members gm ON gm.user_id = b.user_id AND gm.group_id = p_group_id
      WHERE b.group_id = p_group_id
        AND b.game_id = p_game_id
        AND b.bet_type = 'spread'
    ),
    'total_bets', (
      SELECT json_build_object(
        'over', json_agg(
          json_build_object(
            'user_id', b.user_id,
            'username', p.username,
            'display_name', gm.display_name,
            'wager', b.wager_amount,
            'odds', b.odds_at_bet,
            'status', b.bet_status
          )
        ) FILTER (WHERE b.team_bet_on = 'over'),
        'under', json_agg(
          json_build_object(
            'user_id', b.user_id,
            'username', p.username,
            'display_name', gm.display_name,
            'wager', b.wager_amount,
            'odds', b.odds_at_bet,
            'status', b.bet_status
          )
        ) FILTER (WHERE b.team_bet_on = 'under')
      )
      FROM bets b
      JOIN profiles p ON b.user_id = p.id
      LEFT JOIN group_members gm ON gm.user_id = b.user_id AND gm.group_id = p_group_id
      WHERE b.group_id = p_group_id
        AND b.game_id = p_game_id
        AND b.bet_type = 'total'
    )
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- ==================================================
-- FUNCTION: GET POST-GAME RESULTS WITH RIVALRIES
-- ==================================================

CREATE OR REPLACE FUNCTION get_post_game_results(
  p_group_id UUID,
  p_game_id UUID,
  p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_user_bet RECORD;
  v_game RECORD;
BEGIN
  -- Get user's bet for this game
  SELECT * INTO v_user_bet
  FROM bets
  WHERE group_id = p_group_id
    AND game_id = p_game_id
    AND user_id = p_user_id
  LIMIT 1;

  -- Get game info
  SELECT * INTO v_game FROM nfl_games WHERE id = p_game_id;

  -- If user didn't bet, return minimal info
  IF v_user_bet IS NULL THEN
    RETURN json_build_object(
      'user_participated', FALSE,
      'game', row_to_json(v_game)
    );
  END IF;

  RETURN json_build_object(
    'user_participated', TRUE,
    'game', row_to_json(v_game),
    'user_bet', json_build_object(
      'bet_type', v_user_bet.bet_type,
      'team_bet_on', v_user_bet.team_bet_on,
      'wager', v_user_bet.wager_amount,
      'result', v_user_bet.bet_status,
      'profit', v_user_bet.payout_amount - v_user_bet.wager_amount
    ),
    'rivals_comparison', (
      SELECT json_agg(
        json_build_object(
          'rival_id', b.user_id,
          'rival_username', p.username,
          'rival_display_name', gm.display_name,
          'rival_pick', b.team_bet_on,
          'rival_result', b.bet_status,
          'rival_profit', b.payout_amount - b.wager_amount,
          'you_won', v_user_bet.bet_status = 'won' AND b.bet_status = 'lost',
          'they_won', v_user_bet.bet_status = 'lost' AND b.bet_status = 'won',
          'both_won', v_user_bet.bet_status = 'won' AND b.bet_status = 'won',
          'both_lost', v_user_bet.bet_status = 'lost' AND b.bet_status = 'lost',
          'opposite_picks', v_user_bet.team_bet_on != b.team_bet_on
        )
      )
      FROM bets b
      JOIN profiles p ON b.user_id = p.id
      LEFT JOIN group_members gm ON gm.user_id = b.user_id AND gm.group_id = p_group_id
      WHERE b.group_id = p_group_id
        AND b.game_id = p_game_id
        AND b.user_id != p_user_id
    ),
    'summary', json_build_object(
      'beat', (
        SELECT COUNT(*)
        FROM bets b
        WHERE b.group_id = p_group_id
          AND b.game_id = p_game_id
          AND b.user_id != p_user_id
          AND v_user_bet.bet_status = 'won'
          AND b.bet_status = 'lost'
      ),
      'lost_to', (
        SELECT COUNT(*)
        FROM bets b
        WHERE b.group_id = p_group_id
          AND b.game_id = p_game_id
          AND b.user_id != p_user_id
          AND v_user_bet.bet_status = 'lost'
          AND b.bet_status = 'won'
      ),
      'tied_with', (
        SELECT COUNT(*)
        FROM bets b
        WHERE b.group_id = p_group_id
          AND b.game_id = p_game_id
          AND b.user_id != p_user_id
          AND v_user_bet.bet_status = b.bet_status
      )
    )
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- ==================================================
-- VIEW: RIVALRY LEADERBOARD (WHO'S DOMINATING)
-- ==================================================

CREATE OR REPLACE VIEW rivalry_dominance AS
SELECT
  gm.group_id,
  gm.user_id,
  p.username,
  COUNT(DISTINCT opponent.user_id) as rivals_beaten,
  SUM(CASE
    WHEN b1.bet_status = 'won' AND b2.bet_status = 'lost' THEN 1
    ELSE 0
  END) as total_wins_over_rivals,
  SUM(CASE
    WHEN b1.bet_status = 'lost' AND b2.bet_status = 'won' THEN 1
    ELSE 0
  END) as total_losses_to_rivals,
  COALESCE(SUM(
    (b1.payout_amount - b1.wager_amount) - (b2.payout_amount - b2.wager_amount)
  ), 0) as total_profit_vs_rivals
FROM group_members gm
JOIN profiles p ON gm.user_id = p.id
LEFT JOIN bets b1 ON b1.user_id = gm.user_id AND b1.group_id = gm.group_id
LEFT JOIN bets b2
  ON b2.game_id = b1.game_id
  AND b2.group_id = b1.group_id
  AND b2.user_id != gm.user_id
LEFT JOIN group_members opponent
  ON opponent.user_id = b2.user_id
  AND opponent.group_id = gm.group_id
  AND opponent.is_active = TRUE
WHERE gm.is_active = TRUE
  AND b1.bet_status IN ('won', 'lost')
  AND b2.bet_status IN ('won', 'lost')
GROUP BY gm.group_id, gm.user_id, p.username;

COMMENT ON FUNCTION get_rivalry_stats IS 'Comprehensive head-to-head stats between two users in a group.';
COMMENT ON FUNCTION get_user_rivalries IS 'Get all rivalries for a user in a group, sorted by matchup count.';
COMMENT ON FUNCTION get_game_betting_breakdown IS 'Shows who bet on each side of a game within a group.';
COMMENT ON FUNCTION get_post_game_results IS 'Post-game results with rivalry comparison (who you beat/lost to).';
COMMENT ON VIEW rivalry_dominance IS 'Leaderboard showing who dominates their rivals in head-to-head matchups.';
