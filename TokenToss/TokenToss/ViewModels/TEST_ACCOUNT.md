# Test Account Setup

A default test account has been configured for quick testing and development.

## Test Account Credentials

- **Email:** `admin@gmail.com`
- **Password:** `testing`
- **Username:** `admin`

## Usage

### Option 1: Use the UI Button (Recommended)

1. Run the app
2. On the login screen, scroll down to see "Quick Testing"
3. Tap the **"Use Test Account"** button
4. The account will be automatically created (if it doesn't exist) or signed in

### Option 2: Manual Sign In

1. Run the app
2. Enter the credentials above
3. Tap "Sign In"

### Option 3: Programmatic Usage (For Testing/Development)

In your code, you can call:

```swift
await authVM.useTestAccount()
```

## How It Works

The `useTestAccount()` method in `AuthViewModel`:
1. **Tries to sign in** to the account first
2. If the account doesn't exist, it **creates it automatically**
3. Sets up the user profile with username "admin"
4. Authenticates the user

## Notes

- ⚠️ **Development Only**: Remove or disable the test account button before production release
- 🔒 The test account is created in your Supabase database
- 🎯 The account will have all the same capabilities as a regular user
- 💰 If you have a wallet system, it will receive the standard starting balance (e.g., 1000 tokens)

## Security Note

**Before deploying to production:**
1. Remove the "Use Test Account" button from `AuthView.swift`
2. Consider removing or commenting out the `useTestAccount()` method
3. Or wrap it in a `#if DEBUG` check:

```swift
#if DEBUG
func useTestAccount() async {
    // ... implementation
}
#endif
```

## Cleanup

To delete the test account from Supabase:
1. Go to your Supabase Dashboard
2. Navigate to Authentication → Users
3. Find and delete the user with email `admin@gmail.com`
4. Manually delete the associated profile from the `profiles` table if needed
