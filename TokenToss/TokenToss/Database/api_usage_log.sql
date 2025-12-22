-- API Usage Logging Table
-- Tracks external API calls to The Odds API to monitor monthly quota usage
-- Goal: Stay under 500 requests/month

CREATE TABLE IF NOT EXISTS api_usage_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  endpoint TEXT NOT NULL,
  cost INTEGER NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient date-range queries (e.g., monthly usage reports)
CREATE INDEX IF NOT EXISTS idx_api_usage_timestamp ON api_usage_log(timestamp DESC);

-- View to check current month's API usage
CREATE OR REPLACE VIEW api_usage_current_month AS
SELECT
  COUNT(*) as total_calls,
  SUM(cost) as total_cost,
  DATE_TRUNC('month', timestamp) as month
FROM api_usage_log
WHERE timestamp >= DATE_TRUNC('month', CURRENT_TIMESTAMP)
GROUP BY DATE_TRUNC('month', timestamp);

-- View to check daily API usage
CREATE OR REPLACE VIEW api_usage_daily AS
SELECT
  DATE_TRUNC('day', timestamp) as day,
  COUNT(*) as calls,
  SUM(cost) as cost
FROM api_usage_log
GROUP BY DATE_TRUNC('day', timestamp)
ORDER BY day DESC;

-- Comment for documentation
COMMENT ON TABLE api_usage_log IS 'Tracks API calls to The Odds API. Target: <500 calls/month.';
COMMENT ON COLUMN api_usage_log.endpoint IS 'API endpoint called (e.g., americanfootball_nfl/odds)';
COMMENT ON COLUMN api_usage_log.cost IS 'Request cost in credits (1 per region per market)';
