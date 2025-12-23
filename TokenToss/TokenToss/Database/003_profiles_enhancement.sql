-- Profiles Enhancement for Newcomer Onboarding
-- Migration 003: Add betting experience tracking and user preferences

-- ==================================================
-- UPDATE PROFILES TABLE
-- ==================================================

-- Add betting experience level
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS betting_experience TEXT
  DEFAULT 'newcomer'
  CHECK (betting_experience IN ('newcomer', 'intermediate', 'experienced'));

-- Add bet count for experience progression
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_bets_placed INT DEFAULT 0;

-- Add onboarding flags
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS first_bet_date TIMESTAMPTZ;

-- Add user preferences
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{}';
-- preferences structure:
-- {
--   "notifications_enabled": true,
--   "show_betting_tips": true,
--   "preferred_odds_format": "american",
--   "avatar_url": "https://...",
--   "bio": "Just here to beat my friends"
-- }

-- Add profile completeness tracking
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profile_image_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name TEXT;

-- Index for experience-based queries
CREATE INDEX IF NOT EXISTS idx_profiles_experience ON profiles(betting_experience);

COMMENT ON COLUMN profiles.betting_experience IS 'User betting experience: newcomer (<10 bets), intermediate (10-50), experienced (50+)';
COMMENT ON COLUMN profiles.total_bets_placed IS 'Total bets placed across all groups. Used for experience progression.';
COMMENT ON COLUMN profiles.onboarding_completed IS 'Whether user has completed onboarding flow.';
COMMENT ON COLUMN profiles.first_bet_date IS 'Timestamp of first bet placed. Used for anniversary features.';
COMMENT ON COLUMN profiles.preferences IS 'User preferences as JSONB. Flexible for new features.';

-- ==================================================
-- FUNCTION: UPDATE USER EXPERIENCE LEVEL
-- ==================================================

CREATE OR REPLACE FUNCTION update_user_experience_level(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_total_bets INT;
  v_new_experience TEXT;
  v_old_experience TEXT;
BEGIN
  -- Get current bet count
  SELECT COUNT(*) INTO v_total_bets
  FROM bets
  WHERE user_id = p_user_id
  AND bet_status != 'cancelled';

  -- Get current experience level
  SELECT betting_experience INTO v_old_experience
  FROM profiles
  WHERE id = p_user_id;

  -- Determine new experience level
  IF v_total_bets < 10 THEN
    v_new_experience := 'newcomer';
  ELSIF v_total_bets < 50 THEN
    v_new_experience := 'intermediate';
  ELSE
    v_new_experience := 'experienced';
  END IF;

  -- Update profile
  UPDATE profiles
  SET
    total_bets_placed = v_total_bets,
    betting_experience = v_new_experience,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- Set first bet date if this is first bet
  IF v_total_bets = 1 THEN
    UPDATE profiles
    SET first_bet_date = NOW()
    WHERE id = p_user_id;
  END IF;

  RETURN v_new_experience;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- FUNCTION: CHECK IF USER SHOULD SEE BETTING TIPS
-- ==================================================

CREATE OR REPLACE FUNCTION should_show_betting_tips(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_total_bets INT;
  v_preferences JSONB;
  v_show_tips BOOLEAN;
BEGIN
  SELECT total_bets_placed, preferences
  INTO v_total_bets, v_preferences
  FROM profiles
  WHERE id = p_user_id;

  -- Check user preference (default true)
  v_show_tips := COALESCE((v_preferences->>'show_betting_tips')::BOOLEAN, TRUE);

  -- Show tips for first 10 bets if user hasn't disabled
  RETURN v_show_tips AND v_total_bets < 10;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- FUNCTION: GET USER ONBOARDING STATUS
-- ==================================================

CREATE OR REPLACE FUNCTION get_onboarding_status(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_profile RECORD;
  v_group_count INT;
BEGIN
  SELECT * INTO v_profile
  FROM profiles
  WHERE id = p_user_id;

  SELECT COUNT(*) INTO v_group_count
  FROM group_members
  WHERE user_id = p_user_id
  AND is_active = TRUE;

  RETURN json_build_object(
    'onboarding_completed', v_profile.onboarding_completed,
    'betting_experience', v_profile.betting_experience,
    'total_bets', v_profile.total_bets_placed,
    'has_group', v_group_count > 0,
    'first_bet_placed', v_profile.first_bet_date IS NOT NULL,
    'should_show_tips', should_show_betting_tips(p_user_id),
    'steps_completed', json_build_object(
      'profile_created', TRUE,
      'joined_group', v_group_count > 0,
      'placed_first_bet', v_profile.first_bet_date IS NOT NULL,
      'completed_5_bets', v_profile.total_bets_placed >= 5
    )
  );
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- TRIGGER: AUTO-UPDATE EXPERIENCE LEVEL ON BET
-- ==================================================

CREATE OR REPLACE FUNCTION trigger_update_experience_on_bet()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update for new bets that aren't cancelled
  IF NEW.bet_status != 'cancelled' THEN
    PERFORM update_user_experience_level(NEW.user_id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_experience_on_bet_insert
AFTER INSERT ON bets
FOR EACH ROW
EXECUTE FUNCTION trigger_update_experience_on_bet();

-- ==================================================
-- VIEW: USER PROFILE WITH STATS
-- ==================================================

CREATE OR REPLACE VIEW user_profiles_with_stats AS
SELECT
  p.*,
  w.balance,
  w.lifetime_earned,
  w.lifetime_spent,
  COUNT(DISTINCT gm.group_id) as groups_count,
  COUNT(b.id) as total_bets,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'won') as total_wins,
  COUNT(b.id) FILTER (WHERE b.bet_status = 'lost') as total_losses,
  CASE
    WHEN COUNT(b.id) FILTER (WHERE b.bet_status IN ('won', 'lost')) > 0
    THEN ROUND(
      100.0 * COUNT(b.id) FILTER (WHERE b.bet_status = 'won') /
      COUNT(b.id) FILTER (WHERE b.bet_status IN ('won', 'lost')),
      1
    )
    ELSE 0
  END as win_percentage,
  COALESCE(SUM(b.payout_amount - b.wager_amount) FILTER (WHERE b.bet_status = 'won'), 0) as total_profit
FROM profiles p
LEFT JOIN wallets w ON p.id = w.user_id
LEFT JOIN group_members gm ON p.id = gm.user_id AND gm.is_active = TRUE
LEFT JOIN bets b ON p.id = b.user_id
GROUP BY p.id, p.username, p.created_at, p.updated_at, p.betting_experience,
         p.total_bets_placed, p.onboarding_completed, p.first_bet_date,
         p.preferences, p.profile_image_url, p.display_name,
         w.balance, w.lifetime_earned, w.lifetime_spent;

-- ==================================================
-- DEFAULT VALUES FOR EXISTING USERS
-- ==================================================

-- Update existing users with default preferences
UPDATE profiles
SET preferences = '{
  "notifications_enabled": true,
  "show_betting_tips": true,
  "preferred_odds_format": "american"
}'::jsonb
WHERE preferences = '{}'::jsonb OR preferences IS NULL;

-- Update experience levels for existing users based on their bet count
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN SELECT id FROM profiles LOOP
    PERFORM update_user_experience_level(user_record.id);
  END LOOP;
END $$;

COMMENT ON FUNCTION update_user_experience_level IS 'Auto-updates user experience level based on bet count. Triggered on each bet.';
COMMENT ON FUNCTION should_show_betting_tips IS 'Returns whether to show betting tips to user (first 10 bets + user preference).';
COMMENT ON FUNCTION get_onboarding_status IS 'Returns complete onboarding status for user with progress tracking.';
COMMENT ON VIEW user_profiles_with_stats IS 'User profiles enriched with betting stats, balance, and group membership.';
