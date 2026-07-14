Here's the full checklist for the App Store.

App signing

Bundle ID is already set: `com.rigobert.rigobertSays`, team `4MN8W74K9M` (see `ios/Runner.xcodeproj/project.pbxproj`)
Confirm you have an active Apple Developer Program membership ($99/yr) for that team
Register the App ID `com.rigobert.rigobertSays` at developer.apple.com/account (Certificates, Identifiers & Profiles → Identifiers) if not already there, with the Game Center capability enabled
CODE_SIGN_STYLE is Automatic — Xcode will manage the distribution certificate/profile the first time you archive, as long as your Apple ID is added in Xcode → Settings → Accounts

Game Center capability

No `.entitlements` file exists yet in `ios/Runner` — open the project in Xcode, select the Runner target → Signing & Capabilities → "+ Capability" → Game Center
This generates `Runner.entitlements` with `com.apple.developer.game-center` and links it in the build settings — commit that file
Without this the `games_services` calls (`silentSignIn`, `submitScore`, `showLeaderboards`) will fail on real devices

App Store Connect setup

Create the app at appstoreconnect.apple.com (My Apps → +) using bundle ID `com.rigobert.rigobertSays`
Fill in the age rating questionnaire (suitable for all ages)
Complete the App Privacy section (Data Types) — you collect nothing except IAP transaction data handled by Apple, and Game Center player IDs handled by Apple
Set export compliance: the app doesn't use custom encryption beyond what iOS provides, so you can answer "No" / use the standard exemption

In-App Purchases

Go to Monetization → In-App Purchases, create as Consumables:
  • `com.rigobert.rigobertSays.tip_small`
  • `com.rigobert.rigobertSays.tip_medium`
  • `com.rigobert.rigobertSays.tip_large`
(these IDs are already hardcoded in `lib/purchase_service.dart`)
Add a display name, description, and price tier for each
Add localized "review" screenshot for at least one product — required before Apple will review IAPs
Submit the IAPs — they can be submitted together with the first app binary and are reviewed alongside it (first-time IAPs can't be tested in production until approved, but sandbox testing works immediately with a Sandbox tester account)

Game Center leaderboards

Go to the app's Features → Game Center in App Store Connect, enable Game Center, create four leaderboards (Classic) with IDs matching `lib/leaderboard_service.dart`:
  • `com.rigobert.rigobertSays.leaderboard_still`
  • `com.rigobert.rigobertSays.leaderboard_float`
  • `com.rigobert.rigobertSays.leaderboard_spin`
  • `com.rigobert.rigobertSays.leaderboard_both`
Set score format/sort order (higher score is better) and add localized names
Leaderboards are usable in Sandbox as soon as they're created — no publish/review step like Android

Store listing

Short subtitle (30 chars) and description, keywords, support URL
Screenshots for at least one 6.9" (iPhone) size — generate the rest from the same simulator run or use App Store Connect's automatic scaling
App icon is bundled in the binary (`ios/Runner/Assets.xcassets/AppIcon.appiconset`) — verify it's populated from `icon_512*.png`, since a missing icon blocks submission
Privacy policy URL (required) — `privacy_policy.html` already exists in the repo root; host it (e.g. GitHub Pages) and use that URL

Build & upload

Bump `version` in `pubspec.yaml` (currently `1.0.2+10`) — the part before `+` is `CFBundleShortVersionString`, after `+` is `CFBundleVersion`; both map automatically via `FLUTTER_BUILD_NAME`/`FLUTTER_BUILD_NUMBER`
Run `flutter build ipa --release` to produce `build/ios/ipa/rigobert_says.ipa` (does `pod install` + archive + export in one step)
Upload with Xcode's Transporter app, or `xcrun altool --upload-app -f build/ios/ipa/rigobert_says.ipa -t ios -u <apple-id> -p <app-specific-password>`
Processing takes 10–30 minutes before the build appears in App Store Connect

TestFlight

Once processed, add the build under TestFlight, fill in "What to Test"
Internal testers (your own team, up to 100) get access immediately with no review
External testers require a first-time Beta App Review (usually <24h) — use this to validate real IAP + Game Center flows before submitting for full release

Release

Attach the uploaded build to a version in App Store Connect, fill in "What's New", submit for review
Full app review is typically 24–48h; the bundled IAPs are reviewed in the same pass
After approval, choose manual or automatic release

Flutter-specific

`ios/Podfile` has the platform line commented out, which defaults to whatever Xcode/CocoaPods picks — pin `platform :ios, '13.0'` (or whatever minimum you actually test) if you want it explicit
Run `flutter build ipa --release` rather than a plain `flutter build ios` — the latter doesn't produce a signed, App-Store-ready artifact

The Game Center leaderboard IDs have no lead time (usable instantly in sandbox), but the IAPs do need Apple's review before they go live in production — plan the first submission with that in mind.

Lessons from the Wanagram release (same Mac, same team 4MN8W74K9M, 2026-07-13)

Cloud Managed signing is broken for this team — will hit this project too
  This team's Apple ID has an accented name ("Miklós Merényi"). Xcode's default Automatic/Cloud
  Managed "Apple Distribution" certificate encodes that name using decomposed Unicode (NFD) in
  its designated-requirement string, while the actual certificate uses precomposed (NFC).
  `codesign --verify --deep --strict` reports "valid on disk" but "does not satisfy its
  designated Requirement", and App Store Connect rejects the upload with "Validation failed.
  Invalid Signature." This will reproduce on this app the same way it did on Wanagram, since
  it's the same team/account, not something specific to Wanagram's code.
  Fix: stop using Cloud Managed signing for the release build. Generate a certificate the
  traditional way (private key stays local, not cloud-signed):
    1. Keychain Access → Certificate Assistant → Request a Certificate From a Certificate
       Authority... → "Saved to disk" → produces a .certSigningRequest + local private key
    2. developer.apple.com/account/resources/certificates/list → + → Apple Distribution →
       upload the CSR → download the .cer
    3. Double-click the .cer to install (pairs with the local private key automatically —
       confirm with `security find-identity -v -p codesigning`, should now show
       "Apple Distribution: Miklós Merényi (4MN8W74K9M)" with an actual local identity)
    4. developer.apple.com/account/resources/profiles/list → + → App Store Connect
       (Distribution) → this app's App ID → the cert from step 3 → download the
       .mobileprovision, install into ~/Library/MobileDevice/Provisioning Profiles/
       (named by its UUID)
    5. Export with a manual-signing ExportOptions.plist instead of relying on Automatic:
       `signingStyle: manual`, `signingCertificate: Apple Distribution`,
       `provisioningProfiles: {<bundle id>: <profile name>}`
  Always re-verify after exporting: `codesign --verify --deep --strict --verbose=4
  Payload/Runner.app` should say "satisfies its Designated Requirement" — if it says "does not
  satisfy", it's back on Cloud Managed signing somehow.

Keychain prompts may not accept the correct password in this environment
  When codesign/xcodebuild need to use the manually-created private key, the "codesign wants to
  sign using key..." dialog may reject the genuinely correct login password on every retry, even
  though the same password works for Keychain Access and `security unlock-keychain`. Neither
  `security unlock-keychain` nor `security set-key-partition-list` fixed it. What did: Keychain
  Access → My Certificates → (private key under the cert) → Get Info → Access Control tab →
  "Allow all applications to access this item". That sidesteps the broken prompt by
  pre-authorizing access instead of asking for it at sign time.

Xcode 26 / iOS 26 SDK is now required for submission
  Even a perfectly signed build gets rejected with "This app was built with the iOS 18.5 SDK.
  All iOS and iPadOS apps must be built with the iOS 26 SDK or later" if built on an older
  Xcode. After installing Xcode 26, the iOS platform/SDK itself is a separate download:
  `xcodebuild -downloadPlatform iOS` (or Xcode → Settings → Components). Check with
  `xcodebuild -showdestinations` — "Any iOS Device" resolving without an "iOS 26.0 is not
  installed" error confirms it's ready.

Universal (iPhone+iPad) apps need all 4 orientations in the base Info.plist key
  If `UISupportedInterfaceOrientations` (the iPhone key, not `~ipad`) only lists Portrait +
  Landscape but omits `UIInterfaceOrientationPortraitUpsideDown`, App Store Connect rejects with
  "you need to include all of the ... orientations to support iPad multitasking" — even if the
  app is portrait-only in practice. Add all four to the base key regardless of actual behavior.

Missing dSYM for a Dart-native-assets-built framework
  Any Flutter plugin/package built via the native-assets/build-hooks system (look for
  `.dart_tool/hooks_runner/<name>` — Wanagram's case was the `objective_c` package used by FFI
  bridging) doesn't get a dSYM generated by Xcode's archive step, since it isn't compiled as a
  normal Xcode target. App Store Connect rejects with "archive did not include a dSYM... for
  <name> with the expected UUIDs." Fix: `dsymutil -o /tmp/x.dSYM
  <archive>/Products/Applications/Runner.app/Frameworks/<name>.framework/<binary>`, then copy
  the result to `<archive>/dSYMs/<name>.framework.dSYM`. Verify UUIDs match with `dwarfdump
  --uuid` on both the dSYM and the original binary. Needed again after every fresh archive.

Getting a command-line archive into Xcode Organizer
  `xcodebuild archive` doesn't register with Organizer automatically — it only scans
  `~/Library/Developer/Xcode/Archives/<date>/`. Copy it there manually, and delete any older
  archive from that folder first so Organizer can't pick a stale one by accident:
    DATE_DIR=$(date +%Y-%m-%d); mkdir -p ~/Library/Developer/Xcode/Archives/"$DATE_DIR"
    cp -R build/ios/archive/Runner.xcarchive ~/Library/Developer/Xcode/Archives/"$DATE_DIR"/"App $(date '+%-m-%-d-%y, %-I.%M %p').xcarchive"

Prefer `flutter build ipa --build-number=N` over raw `xcodebuild archive`
  Raw `xcodebuild archive` sometimes produced an archive whose Info.plist didn't match what
  pubspec.yaml said (`Generated.xcconfig` staying stale even after `flutter clean` + wiping
  DerivedData — cause never fully identified). `flutter build ipa --release
  --build-number=<N> --export-options-plist=ios/ExportOptions.plist` reliably reports and
  produces the exact version/build requested, and is the officially-supported path anyway.

CocoaPods/Ruby crashes on this account's accented name unless UTF-8 locale is forced
  `pod install --repo-update` (and occasionally plain `pod install`) can crash with "Unicode
  Normalization not appropriate for ASCII-8BIT (Encoding::CompatibilityError)" because this
  Mac's shell has no LANG/LC_ALL set (defaults to C/ASCII). Always prefix pod/xcodebuild
  commands with `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` on this machine.

Default launch image is a blank placeholder
  `flutter build ipa` warns "Launch image is set to the default placeholder icon" — the stock
  Flutter template's `ios/Runner/Assets.xcassets/LaunchImage.imageset` is a transparent 1×1-ish
  image. Easiest fix: regenerate LaunchImage.png/@2x/@3x from the real app icon at a reasonable
  logical size (e.g. 120pt) via `sips -z <px> <px> AppIcon.../Icon-App-1024x1024@1x.png --out
  LaunchImage.imageset/LaunchImage@Nx.png`, and update the storyboard's declared image size to
  match.

iOS Simulator may hang indefinitely in this environment specifically
  `flutter run --debug` on any Simulator here can hang forever on "Waiting for VM Service port
  to be available" with zero Flutter/Dart engine log output, even after a full clean rebuild,
  fresh CocoaPods, wiped DerivedData, and with Impeller disabled — while the Simulator's own
  SpringBoard UI renders fine. Root cause not conclusively identified (possibly a Metal/GPU
  passthrough limitation specific to this session/host), and it did not affect testing on a
  physical device. `flutter run --release` doesn't work around it either — Release mode is
  flatly unsupported on Simulator by Flutter's own tooling. Workaround: `flutter build ios
  --release --simulator` (a plain Xcode build, no `flutter run` debug-attach step involved) then
  `xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch
  booted <bundle id>` — or just use a physical device for testing/screenshots if the Simulator
  hang recurs.
