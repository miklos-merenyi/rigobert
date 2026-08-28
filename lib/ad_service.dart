import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ── Ad unit IDs ───────────────────────────────────────────────────────────────
// Replace the kRelease* constants with your real AdMob unit IDs once you have
// created them in the AdMob console (https://admob.google.com).
//
// The kTest* IDs below are Google's official test IDs — safe to use during
// development; they never generate real revenue or policy risk.

const _kTestAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
const _kTestIosInterstitialId     = 'ca-app-pub-3940256099942544/4411468910';

// TODO: replace with your real AdMob interstitial unit IDs before shipping.
const _kReleaseAndroidInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
const _kReleaseIosInterstitialId     = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

String get _interstitialAdUnitId {
  if (kDebugMode) {
    return Platform.isIOS ? _kTestIosInterstitialId : _kTestAndroidInterstitialId;
  }
  return Platform.isIOS ? _kReleaseIosInterstitialId : _kReleaseAndroidInterstitialId;
}

// Show an interstitial ad every N games (for non-tippers only).
const kAdEveryNGames = 3;

// ── AdService ─────────────────────────────────────────────────────────────────

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  /// Call once from main() after MobileAds is initialised.
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (_isLoading || _interstitialAd != null) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
          debugPrint('[AdService] interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _interstitialAd = null;
          debugPrint('[AdService] failed to load interstitial: $error');
        },
      ),
    );
  }

  /// Shows the interstitial (if one is ready) and resolves when the player
  /// dismisses it. Immediately starts loading the next ad.
  /// Returns true if an ad was shown, false if none was ready.
  Future<bool> showIfReady() async {
    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('[AdService] no ad ready — skipping');
      _loadInterstitial(); // try to get one for next time
      return false;
    }

    _interstitialAd = null; // claim it before showing

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        completer.complete();
        _loadInterstitial(); // pre-load for the next interval
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] failed to show interstitial: $error');
        ad.dispose();
        completer.complete();
        _loadInterstitial();
      },
    );

    await ad.show();
    await completer.future;
    return true;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
