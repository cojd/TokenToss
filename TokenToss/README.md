# TokenToss

A social betting app for NFL games using virtual tokens.

## Setup

### The Odds API Configuration

This app uses [The Odds API](https://the-odds-api.com) to fetch live NFL game odds.

1. **Get an API Key**
   - Sign up at [the-odds-api.com](https://the-odds-api.com)
   - Choose a plan that includes at least 500 requests/month
   - Copy your API key

2. **Configure the API Key**
   - Open `TokenToss/Services/OddsAPIService.swift`
   - Replace `"YOUR_ODDS_API_KEY"` with your actual API key

### API Usage & Caching

The app implements smart caching to stay under 500 API calls/month:

**Caching Strategy:**
- **Cache Duration:** 10 minutes
- **Auto-refresh:** Updates from Supabase cache only (no API calls)
- **Smart Fetching:** Only calls API when:
  - Cache is expired (>10 minutes old)
  - There are upcoming games
  - Games haven't started or completed

**Expected Usage:**
- ~3-4 API calls per day during NFL season
- ~90-120 API calls per month
- Well within 500/month limit ✅

**Monitoring API Usage:**
- API calls are logged in the `api_usage_log` Supabase table
- Response headers show remaining requests
- Check console logs for "📊 API Requests remaining" messages

### Supabase Setup

You'll need to create an `api_usage_log` table in Supabase:

```sql
CREATE TABLE api_usage_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  endpoint TEXT NOT NULL,
  cost INTEGER NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Optional: Create index for faster queries
CREATE INDEX idx_api_usage_timestamp ON api_usage_log(timestamp DESC);
```

## Development

### Manual API Refresh

By default, the app uses cached data. To force a fresh API call during development:

```swift
await viewModel.forceRefreshFromAPI()
```

**Use this sparingly** to avoid exhausting your API quota!
