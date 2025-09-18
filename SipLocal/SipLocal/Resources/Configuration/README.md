# Configuration Setup

## Config.plist Setup

This directory contains the app's configuration files. The `Config.plist` file contains sensitive API keys and is excluded from version control for security.

### Setup Instructions:

1. **Copy the template:**
   ```bash
   cp Config.template.plist Config.plist
   ```

2. **Update Config.plist with your actual API keys:**
   - `SquareApplicationID`: Your Square application ID
   - `StripePublishableKey`: Your Stripe publishable key  
   - `OneSignalAppID`: Your OneSignal application ID
   - `Environment`: Set to "Development" or "Production"

### Security Notes:

- ✅ `Config.plist` is excluded from version control
- ✅ Template file shows required structure without exposing keys
- ✅ App will fail fast if keys are missing or invalid
- ⚠️ Never commit the actual `Config.plist` file

### Files in this directory:

- `Config.template.plist` - Template showing required keys (safe to commit)
- `Config.plist` - Actual configuration with API keys (excluded from git)
- `GoogleService-Info.plist` - Firebase configuration
- `Info.plist` - App metadata and settings
- `SipLocal.entitlements` - App capabilities and permissions
