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
- [x] Swapped placeholder AdMob App IDs (Android + iOS) and interstitial ad unit IDs for real ones from [apps.admob.com](https://apps.admob.com) (`1773413`)
- [x] Hosted `app-ads.txt` at the developer website root (`https://miklos-merenyi.github.io/app-ads.txt`) so AdMob can verify both apps — domain confirmed live via both the Play Store listing and the iOS Support URL
- [x] Fixed `flutter build ios` (was failing: CocoaPods couldn't resolve `webview_flutter_wkwebview`, an SPM-only transitive dep of `google_mobile_ads`) — first by disabling SPM (`3f4599c`), then properly by bumping `google_mobile_ads`/`games_services` to SPM-capable versions (`6523e4b`)
- [x] Replaced the discontinued, non-SPM `soundpool` (vendored fork) with `flutter_soloud` (`d22a8a7`)
- [x] Removed CocoaPods integration from the iOS project entirely — every plugin is now SPM-only (`453cce8`)
- [x] Diagnosed the 3.7MB→12.7MB Android size jump: `flutter_soloud` bundles Opus/Ogg/Vorbis/FLAC codec libs we don't use (all assets are MP3) alongside its engine; `NO_XIPH_LIBS=true` in `android/gradle.properties` cuts ~4.6MB of that (`3c5d80c`)

## To do

### App Check rollout
- [ ] Push commits: `git push`
- [ ] Ship a release build (TestFlight / Play internal testing) — Play Integrity and DeviceCheck only work on real signed builds, not debug/simulator
- [ ] Watch Firebase Console → App Check → **Metrics** for a few days to confirm real traffic is verified, not just rejected
- [ ] Once metrics look healthy, click **Enforce** per service (Firestore, Analytics, etc.) in App Check
- [ ] Remove any temporary `getToken()` / `debugPrint` debug-token snippet from `main.dart` if still present

### AdMob
- [ ] Verify `NSUserTrackingUsageDescription` wording is final for App Store review
- [ ] Test the interstitial actually shows/dismisses correctly on a real device before release
- [ ] Check AdMob → Apps → [app] → App settings for both apps a day or two after publishing `app-ads.txt` — confirm status shows verified, not just pending

### iOS build / audio
- [ ] **Listen-test the instrument notes on a real device** (rapid button presses, queued combos, the melody intro) — `flutter_soloud` should avoid the tail-click that `audioplayers` had, same as `soundpool` did, but this hasn't been confirmed by ear yet
- [x] Xcode's Strip Style → Non-Global Symbols (needed for `flutter_soloud`'s SPM package, which can't set this itself) — applied automatically to `project.pbxproj` on a fresh SPM resolve, no manual step needed after all

### Optional hardening
- [ ] Consider restricting the Firebase API keys in Google Cloud Console → APIs & Services → Credentials (Android key → package name + SHA-1, iOS key → bundle ID) as defense in depth alongside App Check
- [ ] Figure out what caused the earlier git revert that wiped uncommitted changes (AdMob work, App Check work) — happened once already, worth avoiding a repeat
