# Credential Rotation Log

Date: 2025-09-28
Prepared by: Codex assistant

## Inventory of Exposed Credentials

1. **Stripe Publishable Key**  
   - Value: _stored outside repository (see developer-only Config.secrets.plist or STRIPE_PUBLISHABLE_KEY env var)_  
   - Source (runtime): `Config.secrets.plist` (ignored) or `STRIPE_PUBLISHABLE_KEY` environment variable  
   - Consumer code: `SipLocal/SipLocal/Views/Common/SipLocalApp.swift` (via `AppConfiguration.configurationValue`)  
   - Status: Rotated 2025-09-28; removed from tracked Config.plist.  
   - Follow-up: Scrub old key from git history and distribute new secret via secure channel.

2. **Square Application ID**  
   - Value: `sq0idp-e4abRkjlBijc_l97fVO62Q`  
   - Source file: `SipLocal/SipLocal/Resources/Configuration/Config.plist:5`  
   - Consumer code: `SipLocal/SipLocal/Views/Common/SipLocalApp.swift`  
   - Immediate action: Regenerate application ID (if needed) or create a new application credential in Square Developer portal.  
   - Follow-up: Update configuration loading mechanism and purge old value from repository history.

3. **OneSignal App ID**  
   - Value: `f626f99f-94ea-4859-bac9-10911153f295`  
   - Source file: `SipLocal/SipLocal/Resources/Configuration/Config.plist:9`  
   - Consumer code: `SipLocal/SipLocal/Views/Common/SipLocalApp.swift`  
   - Immediate action: Generate a new OneSignal App ID or migrate to environment-based configuration.  
   - Follow-up: Remove legacy ID from code history post-rotation.

4. **Firebase iOS API Key**  
   - Value: `AIzaSyCDRQYi_X5QkxJmV3xVDchuOSvFZi4y4Nw`  
   - Source file: `SipLocal/SipLocal/Resources/Configuration/GoogleService-Info.plist:6`  
   - Consumer code: Firebase initialization (bundled plist)  
   - Immediate action: Regenerate API key in Google Cloud Console and download a sanitized config for the app.  
   - Follow-up: Store new config outside of version control or use encrypted secrets management.

5. **Google Maps API Key (Android)**  
   - Value: `AIzaSyDgUUetZc96lAvwUw719iegNwNXn1LEpWE`  
   - Source file: `SipLocalAndroid/app/src/main/AndroidManifest.xml:23`  
   - Consumer code: Android Maps SDK via manifest metadata.  
   - Immediate action: Restrict or regenerate Maps key in Google Cloud Console; move key to `local.properties` or encrypted resource not tracked by git.  
   - Follow-up: Clean old key from commits.

6. **Square Sandbox Application ID (Android assets)**  
   - Value: `sandbox-sq0idb-rQ0tQ8bixxpZyp3kiP4SEA`  
   - Source files: `SipLocalAndroid/app/src/main/assets/coffee_shops.json`, `SipLocalAndroid/app/src/main/res/raw/coffee_shops.json`  
   - Immediate action: Confirm whether sandbox key requires rotation; consider removing from public repo if unnecessary.  
   - Follow-up: Replace with mock data or load dynamically at runtime.

## Next Actions Checklist

- [ ] Rotate each credential listed above at its provider.  
- [ ] Update client applications to consume secrets from secure storage (e.g., env vars, encrypted config).  
- [ ] Remove sensitive files from git using `git filter-repo` or GitHub secret scanning remediation.  
- [ ] Strengthen `.gitignore` (ensure `**/build/`, correct `gradle.properties` rule, enforce `*.plist`).  
- [ ] Add pre-commit/CI scanning (git-secrets, trufflehog) to catch future exposures.  
- [ ] Document new deployment process for distributing rotated keys safely.

