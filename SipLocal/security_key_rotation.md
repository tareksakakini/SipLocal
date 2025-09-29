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
   - Status: Rotation skipped (Square does not issue alternate IDs); treat as public identifier.  
   - Follow-up: Limit exposure to trusted builds, keep `.plist` out of git history, and document that the ID is public-only.

3. **OneSignal App ID**  
   - Value: `f626f99f-94ea-4859-bac9-10911153f295`  
   - Source file: `SipLocal/SipLocal/Resources/Configuration/Config.plist:9`  
   - Consumer code: `SipLocal/SipLocal/Views/Common/SipLocalApp.swift`  
   - Status: Rotation deferred (treated as public identifier); continue to avoid committing replacements and prefer env/ignored overrides.  
   - Follow-up: Re-evaluate if future leaks or OneSignal policy changes require issuing a new app.

4. **Firebase iOS API Key**  
   - Value: _stored outside repository (GoogleService-Info.secrets.plist or FIREBASE_OPTIONS_PATH)_  
   - Source (runtime): `GoogleService-Info.secrets.plist` (ignored) or external path via `FIREBASE_OPTIONS_PATH`  
   - Consumer code: `SipLocal/SipLocal/Views/Common/SipLocalApp.swift` loads options with `FirebaseOptions(contentsOfFile:)`  
   - Status: Existing key preserved locally; removed from tracked `GoogleService-Info.plist`.  
   - Follow-up: Rotate key in Firebase Console when ready and update the ignored secrets file; scrub old key from git history.

5. **Google Maps API Key (Android)**  
   - Value: `AIzaSyDgUUetZc96lAvwUw719iegNwNXn1LEpWE`  
   - Source file: `SipLocalAndroid/app/src/main/AndroidManifest.xml:23`  
   - Consumer code: Android Maps SDK via manifest metadata.  
   - Immediate action: Restrict or regenerate Maps key in Google Cloud Console; move key to `local.properties` or encrypted resource not tracked by git.  
   - Follow-up: Clean old key from commits.

7. **Square OAuth Migration Scripts**  
   - Value: Legacy access/refresh tokens embedded in `SipLocalBackend/functions/simple-migrate.js` (removed) and `functions/src/migrate.ts` sample data  
   - Status: `simple-migrate.js` removed from repo; migrate.ts still references historical token data for documentation.  
   - Follow-up: Rotate any Square tokens that appeared in those scripts and ensure future migrations read credentials from secure storage.

## Next Actions Checklist

- [ ] Rotate each credential listed above at its provider.  
- [ ] Update client applications to consume secrets from secure storage (e.g., env vars, encrypted config).  
- [ ] Remove sensitive files from git using `git filter-repo` or GitHub secret scanning remediation.  
- [ ] Strengthen `.gitignore` (ensure `**/build/`, correct `gradle.properties` rule, enforce `*.plist`).  
- [ ] Add pre-commit/CI scanning (git-secrets, trufflehog) to catch future exposures.  
- [ ] Document new deployment process for distributing rotated keys safely.

