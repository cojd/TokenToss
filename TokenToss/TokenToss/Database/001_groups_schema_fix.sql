-- Migration 001: Groups Schema - FIXED
-- Run this to fix the view dependency issue

-- Drop the problematic view if it exists
DROP VIEW IF EXISTS group_members_detailed CASCADE;

-- Recreate groups_summary view without depending on bets.group_id
DROP VIEW IF EXISTS groups_summary CASCADE;
CREATE OR REPLACE VIEW groups_summary AS
SELECT
  g.*,
  get_group_member_count(g.id) as member_count,
  p.username as creator_username
FROM groups g
LEFT JOIN profiles p ON g.created_by = p.id
WHERE g.is_active = TRUE;

-- Note: group_members_detailed view will be created in Migration 002
-- after the group_id column is added to the bets table
