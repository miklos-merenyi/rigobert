# Next Steps

Working notes from the exposed-API-key incident and the App Check / AdMob work that followed. Check items off as you go.

## Background

A Google API key (Firebase `AIzaSy...` key, from `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`) was pushed to a public GitHub repo. Firebase API keys are project identifiers, not secrets — they don't grant billing access — so the fix was **Firebase App Check** (proving requests come from your real app) rather than rotating the key or rewriting git history.

## Done

- [x] Registered Android SHA-1/SHA-256 with Firebase (via Play Console → App signing)
- [x] Created a DeviceCheck key in Apple Developer Console, registered with Firebase
- [x] Added `firebase_app_check` dependency
- [x] Activated App Check in `main.dart` (debug provider in debug builds, Play Integrity / DeviceCheck in release)
- [x] Registered a debug token in Firebase Console for local testing
- [x] Re-added AdMob interstitial ads (`ad_service.dart`, manifest/plist entries) after a git revert wiped the working tree
- [x] Committed App Check (`e2715d4`) and AdMob (`0fbdeff`) changes

## To do

### App Check rollout
- [ ] Push commits: `git push`
- [ ] Ship a release build (TestFlight / Play internal testing) — Play Integrity and DeviceCheck only work on real signed builds, not debug/simulator
- [ ] Watch Firebase Console → App Check → **Metrics** for a few days to confirm real traffic is verified, not just rejected
- [ ] Once metrics look healthy, click **Enforce** per service (Firestore, Analytics, etc.) in App Check
- [ ] Remove any temporary `getToken()` / `debugPrint` debug-token snippet from `main.dart` if still present

### AdMob
- [ ] **Before any production release:** swap the placeholder AdMob App IDs in `AndroidManifest.xml` and `Info.plist` — they're currently Google's public **test IDs** (`ca-app-pub-3940256099942544~...`), not real ones. Get real IDs from [apps.admob.com](https://apps.admob.com)
- [ ] Verify `NSUserTrackingUsageDescription` wording is final for App Store review
- [ ] Test the interstitial actually shows/dismisses correctly on a real device before release

### Optional hardening
- [ ] Consider restricting the Firebase API keys in Google Cloud Console → APIs & Services → Credentials (Android key → package name + SHA-1, iOS key → bundle ID) as defense in depth alongside App Check
- [ ] Figure out what caused the earlier git revert that wiped uncommitted changes (AdMob work, App Check work) — happened once already, worth avoiding a repeat
