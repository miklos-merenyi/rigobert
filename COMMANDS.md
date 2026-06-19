adb install -r build/app/outputs/flutter-apk/app-debug.apk
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.rigobert.rigobertSays
ios-deploy --bundle build/ios/iphoneos/Runner.app
flutter build apk --release
flutter build appbundle --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
