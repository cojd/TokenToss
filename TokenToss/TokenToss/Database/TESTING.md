# Testing The Odds API Caching Implementation

## Pre-Testing Setup

1. **Set up Supabase table**
   ```sql
   -- Run the SQL in api_usage_log.sql
   ```

2. **Configure API Key**
   - Replace `YOUR_ODDS_API_KEY` in `OddsAPIService.swift:14`

## Testing Scenarios

### Scenario 1: Initial Load (First API Call)
**Expected Behavior:**
- App loads games from API (first time, no cache)
- Console shows: `📞 Calling Odds API - cache expired`
- Console shows: `📊 API Requests remaining: XXX`
- Games displayed in UI
- Cache status shows "API called: just now"

### Scenario 2: Refresh Within 10 Minutes (Cache Hit)
**Steps:**
1. Wait 30 seconds
2. Pull to refresh OR tap refresh button

**Expected Behavior:**
- Console shows: `💾 Using cached data - API call skipped`
- No API call made
- Games still displayed
- Cache status still shows previous API call time
- "Updated: X seconds ago" changes

### Scenario 3: Refresh After 10 Minutes (Cache Expired)
**Steps:**
1. Wait >10 minutes
2. Pull to refresh OR tap refresh button

**Expected Behavior:**
- Console shows: `📞 Calling Odds API - cache expired`
- New API call made
- Console shows updated request count
- Cache status updates to "API called: just now"

### Scenario 4: Auto-Refresh Timer (Cache Only)
**Steps:**
1. Keep app open for 60+ seconds
2. Observe auto-refresh behavior

**Expected Behavior:**
- Every 60 seconds, console shows database queries
- NO API calls (unless cache expired)
- "Updated: X seconds ago" resets every 60 seconds
- Cache status unchanged

### Scenario 5: No Upcoming Games (Smart Skip)
**Expected Behavior:**
- If all games are completed or in-progress
- Console shows: `⏭️ No upcoming games - skipping API call`
- No API call even if cache expired

## Monitoring API Usage

### Console Logs to Watch
- `📞 Calling Odds API - cache expired` = API call made
- `💾 Using cached data - API call skipped` = Cache hit
- `⏭️ No upcoming games - skipping API call` = Smart skip
- `📊 API Requests remaining: XXX` = Quota tracking

### Supabase Monitoring
Query to check daily usage:
```sql
SELECT * FROM api_usage_daily ORDER BY day DESC LIMIT 30;
```

Query to check current month:
```sql
SELECT * FROM api_usage_current_month;
```

## Success Criteria

✅ **Day 1 Testing:** Should see max 5-6 API calls
✅ **Cache Working:** Multiple refreshes within 10 min = 0 new API calls
✅ **Auto-Refresh:** Timer refreshes don't trigger API calls
✅ **Smart Logic:** No API calls when no upcoming games
✅ **Target Met:** <500 calls/month projected usage

## Expected API Call Pattern

**Typical Day (with active usage):**
- Morning: 1 API call (first load)
- Afternoon: 1 API call (cache expired after 10 min idle)
- Evening: 1 API call (cache expired)
- Late night: 1 API call (checking game results)

**Total:** ~3-4 calls/day × 30 days = 90-120 calls/month ✅

## Troubleshooting

**Too many API calls:**
- Check console for `📞 Calling Odds API` frequency
- Verify `cacheDuration` is set to 600 seconds (10 min)
- Check `shouldFetchFromAPI()` logic

**No data showing:**
- Verify API key is set correctly
- Check for error messages in console
- Verify Supabase connection

**API calls still every 60 seconds:**
- Verify timer calls `refreshFromCache()` not `loadGames()`
- Check `startAutoRefresh()` implementation
