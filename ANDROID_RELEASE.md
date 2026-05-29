Here's the full checklist for Google Play:
App signing

Run flutter build appbundle --release to generate the .aab
Create an upload keystore: keytool -genkey -v -keystore rigobert.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rigobert
Add signing config to android/app/build.gradle.kts pointing at that keystore
Google Play manages the final signing key (Play App Signing) — you just upload with your key

Google Play Console setup

Create a new app at play.google.com/console
Set up your app's content rating (fill in the questionnaire — this game is suitable for all ages)
Complete the data safety form (you collect nothing except IAP receipts via Google's own systems)
Set the target audience (all ages, no children-directed content needed)

In-App Products

Go to Monetise → In-app products → Managed products
Create tip_small, tip_medium, tip_large as consumables
Publish each product (they need to be active before you can test them)

Play Games Leaderboards

Enable the Google Play Games Services API for your app in the Play Console (Grow → Play Games Services → Setup and management → Configuration)
Create four leaderboards under Leaderboards:
  • STILL  → copy the resulting ID into leaderboard_service.dart as _kAndroidStill
  • FLOAT  → _kAndroidFloat
  • SPIN   → _kAndroidSpin
  • BOTH   → _kAndroidBoth
Add your SHA-1 fingerprint(s) under the linked app (debug + release)
Publish the Play Games configuration (it must be published before scores can be submitted in production)
The games_services plugin needs no extra AndroidManifest.xml entries — the plugin handles the metadata tag automatically

Store listing

Short description (80 chars), full description
At least 2 screenshots per supported screen size (phone mandatory, tablet optional)
Feature graphic (1024×500 px) — could be a stylised banner using the crown + R/G/B colours
App icon (512×512 — you already have icon_512_crown.png ✓)
Privacy policy URL (required even if you collect nothing — host a simple one on GitHub Pages)

Release

Start with Internal Testing, then Closed/Open Testing before production — lets you test real IAP
Target API level must be 35 (Android 15) for new apps in 2025 — check targetSdk in build.gradle.kts
minSdk should be 21 or higher

Flutter-specific

Add android:enableOnBackInvokedCallback="true" to AndroidManifest.xml (required for Android 14+)
Check uses-permission — you probably only need com.android.vending.BILLING for IAP (the in_app_purchase plugin adds this automatically)

The IAP registration is the only thing that has a meaningful lead time — products need to be in "active" state before the app can query prices, and that can take a few hours after first creation.
Want me to check your build.gradle.kts target SDK and AndroidManifest.xml now?
