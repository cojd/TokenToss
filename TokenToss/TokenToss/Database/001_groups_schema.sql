-- Groups and Group Membership Schema
-- Friend-first betting: Small, tight-knit competition groups (5-15 people)
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
  weekly_token_allowance INT DEFAULT 500, -- Weekly token refresh amount
  allowance_day TEXT DEFAULT 'Sunday' CHECK (allowance_day IN ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')),
  group_image_url TEXT,

  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  description TEXT
);

-- Indexes for efficient queries
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

  -- Member customization within this group
  display_name TEXT, -- Optional custom nickname within this group

  -- Role and status
  role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  is_active BOOLEAN DEFAULT TRUE,

  -- Weekly allowance tracking
  last_allowance_date DATE,
  allowance_received_this_week BOOLEAN DEFAULT FALSE,

  PRIMARY KEY (group_id, user_id)
);

-- Indexes for efficient member lookups
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

  UNIQUE(group_id, invited_user_id) -- Can't invite same user to same group twice
);

-- Indexes for invitation queries
CREATE INDEX IF NOT EXISTS idx_invitations_invited_user ON group_invitations(invited_user_id, status);
CREATE INDEX IF NOT EXISTS idx_invitations_group ON group_invitations(group_id, status);

-- ==================================================
-- FUNCTIONS
-- ==================================================

-- Function: Get group member count
CREATE OR REPLACE FUNCTION get_group_member_count(group_id_param UUID)
RETURNS INT AS $$
  SELECT COUNT(*)::INT
  FROM group_members
  WHERE group_id = group_id_param AND is_active = TRUE;
$$ LANGUAGE SQL STABLE;

-- Function: Check if user can join group
CREATE OR REPLACE FUNCTION can_join_group(group_id_param UUID, user_id_param UUID)
RETURNS BOOLEAN AS $$
DECLARE
  current_member_count INT;
  group_limit INT;
  is_already_member BOOLEAN;
BEGIN
  -- Check if already a member
  SELECT EXISTS(
    SELECT 1 FROM group_members
    WHERE group_id = group_id_param
    AND user_id = user_id_param
    AND is_active = TRUE
  ) INTO is_already_member;

  IF is_already_member THEN
    RETURN FALSE;
  END IF;

  -- Check member limit
  SELECT member_limit INTO group_limit FROM groups WHERE id = group_id_param;
  SELECT get_group_member_count(group_id_param) INTO current_member_count;

  RETURN current_member_count < group_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Join group (accepts invitation or direct join if allowed)
CREATE OR REPLACE FUNCTION join_group(
  group_id_param UUID,
  user_id_param UUID,
  invitation_id_param UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  can_join BOOLEAN;
  result JSON;
BEGIN
  -- Check if user can join
  SELECT can_join_group(group_id_param, user_id_param) INTO can_join;

  IF NOT can_join THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'Cannot join group: already a member or group is full'
    );
  END IF;

  -- Add user to group
  INSERT INTO group_members (group_id, user_id)
  VALUES (group_id_param, user_id_param);

  -- Mark invitation as accepted if provided
  IF invitation_id_param IS NOT NULL THEN
    UPDATE group_invitations
    SET status = 'accepted', responded_at = NOW()
    WHERE id = invitation_id_param;
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'group_id', group_id_param,
    'user_id', user_id_param
  );
END;
$$ LANGUAGE plpgsql;

-- Function: Leave group
CREATE OR REPLACE FUNCTION leave_group(
  group_id_param UUID,
  user_id_param UUID
)
RETURNS JSON AS $$
DECLARE
  is_last_admin BOOLEAN;
BEGIN
  -- Check if user is the last admin
  SELECT COUNT(*) = 1 INTO is_last_admin
  FROM group_members
  WHERE group_id = group_id_param
  AND role = 'admin'
  AND is_active = TRUE
  AND user_id = user_id_param;

  IF is_last_admin THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'Cannot leave: you are the last admin. Transfer admin role first or delete the group.'
    );
  END IF;

  -- Mark member as inactive (soft delete to preserve bet history)
  UPDATE group_members
  SET is_active = FALSE
  WHERE group_id = group_id_param AND user_id = user_id_param;

  RETURN json_build_object('success', TRUE);
END;
$$ LANGUAGE plpgsql;

-- Function: Grant weekly allowance to all group members
CREATE OR REPLACE FUNCTION grant_weekly_allowance(group_id_param UUID)
RETURNS JSON AS $$
DECLARE
  allowance_amount INT;
  members_updated INT;
  current_day TEXT;
  allowance_day_config TEXT;
BEGIN
  -- Get group configuration
  SELECT weekly_token_allowance, allowance_day
  INTO allowance_amount, allowance_day_config
  FROM groups
  WHERE id = group_id_param;

  -- Get current day of week
  SELECT TO_CHAR(CURRENT_DATE, 'Day') INTO current_day;
  current_day := TRIM(current_day);

  -- Check if it's the right day for allowance
  IF current_day != allowance_day_config THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'Not allowance day',
      'current_day', current_day,
      'allowance_day', allowance_day_config
    );
  END IF;

  -- Grant allowance to all members who haven't received it this week
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

  -- Mark members as having received allowance
  UPDATE group_members
  SET allowance_received_this_week = TRUE,
      last_allowance_date = CURRENT_DATE
  WHERE group_id = group_id_param
  AND is_active = TRUE;

  RETURN json_build_object(
    'success', TRUE,
    'members_updated', members_updated,
    'allowance_amount', allowance_amount
  );
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- VIEWS
-- ==================================================

-- View: Group member details with user info
CREATE OR REPLACE VIEW group_members_detailed AS
SELECT
  gm.group_id,
  gm.user_id,
  gm.joined_at,
  gm.display_name,
  gm.role,
  gm.is_active,
  p.username,
  w.balance as tokens,
  (SELECT COUNT(*) FROM bets b WHERE b.user_id = gm.user_id AND b.group_id = gm.group_id) as total_bets,
  (SELECT COUNT(*) FROM bets b WHERE b.user_id = gm.user_id AND b.group_id = gm.group_id AND b.bet_status = 'won') as bets_won,
  (SELECT COUNT(*) FROM bets b WHERE b.user_id = gm.user_id AND b.group_id = gm.group_id AND b.bet_status = 'lost') as bets_lost
FROM group_members gm
JOIN profiles p ON gm.user_id = p.id
LEFT JOIN wallets w ON gm.user_id = w.user_id
WHERE gm.is_active = TRUE;

-- View: Group summary with member count
CREATE OR REPLACE VIEW groups_summary AS
SELECT
  g.*,
  get_group_member_count(g.id) as member_count,
  p.username as creator_username
FROM groups g
LEFT JOIN profiles p ON g.created_by = p.id
WHERE g.is_active = TRUE;

-- ==================================================
-- COMMENTS FOR DOCUMENTATION
-- ==================================================

COMMENT ON TABLE groups IS 'Friend-first betting groups. Small tight-knit competition (5-15 people).';
COMMENT ON TABLE group_members IS 'Group membership with role-based access. Soft delete preserves bet history.';
COMMENT ON TABLE group_invitations IS 'Group invitations with expiration. Prevents duplicate invites.';

COMMENT ON COLUMN groups.member_limit IS 'Max members allowed. Default 15 for intimate competition.';
COMMENT ON COLUMN groups.trash_talk_enabled IS 'Allow friendly rivalry features and notifications.';
COMMENT ON COLUMN groups.weekly_token_allowance IS 'Tokens granted to each member weekly. Default 500.';

COMMENT ON FUNCTION get_group_member_count IS 'Returns active member count for a group.';
COMMENT ON FUNCTION can_join_group IS 'Checks if user can join group (not full, not already member).';
COMMENT ON FUNCTION join_group IS 'Add user to group, optionally accepting an invitation.';
COMMENT ON FUNCTION leave_group IS 'Remove user from group (soft delete). Prevents last admin from leaving.';
COMMENT ON FUNCTION grant_weekly_allowance IS 'Grant weekly token allowance to all active group members.';
