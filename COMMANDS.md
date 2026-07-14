adb install -r build/app/outputs/flutter-apk/app-debug.apk
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.rigobert.rigobertSays
ios-deploy --bundle build/ios/iphoneos/Runner.app
flutter build apk --release
flutter build appbundle --release
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Dev build & install
flutter build apk --release
adb devices | tail -n +2 | cut -sf 1 | xargs -I {} -P 4 adb -s {} install -r build/app/outputs/flutter-apk/app-debug.apk

# App Store archive (release, manual signing — see IOS_RELEASE.md for why not automatic)
# 0. If you tested on Simulator since the last device build, clean first — native-assets
#    caching doesn't reliably invalidate between Simulator/device targets:
flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# 1. Build archive + IPA
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 flutter build ipa --release \
    --export-options-plist=ios/ExportOptionsAppStore.plist

# 2. Fix the objective_c.framework dSYM (always missing — built via Dart native-assets,
#    not a normal Xcode target, so Xcode never generates a dSYM for it)
BIN=build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/objective_c.framework/objective_c
dsymutil -o /tmp/objc.dSYM "$BIN"
cp -R /tmp/objc.dSYM build/ios/archive/Runner.xcarchive/dSYMs/objective_c.framework.dSYM

# 3. Copy into Xcode's Archives folder so Organizer picks it up (a CLI archive doesn't
#    register itself — Organizer only scans ~/Library/Developer/Xcode/Archives/<date>/)
DATE_DIR=$(date +%Y-%m-%d)
mkdir -p ~/Library/Developer/Xcode/Archives/"$DATE_DIR"
rm -rf ~/Library/Developer/Xcode/Archives/"$DATE_DIR"/Rigobert*.xcarchive
cp -R build/ios/archive/Runner.xcarchive ~/Library/Developer/Xcode/Archives/"$DATE_DIR"/"Rigobert Says $(date '+%-m-%-d-%y, %-I.%M %p').xcarchive"

# 4. Verify before trusting it — both must say "arm64", not x86_64
lipo -info build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner
lipo -info build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/objective_c.framework/objective_c
cd /tmp && rm -rf check && mkdir check && cd check && unzip -q /Users/mermik/Git/rigobert/build/ios/ipa/*.ipa && codesign --verify --deep --strict --verbose=4 Payload/*.app
