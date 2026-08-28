import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Product IDs ───────────────────────────────────────────────────────────────
// iOS (App Store Connect) uses reverse-domain IDs; Android (Play Console) does not allow dots.
const _kIosTipS = 'com.rigobert.rigobertSays.tip_small';
const _kIosTipM = 'com.rigobert.rigobertSays.tip_medium';
const _kIosTipL = 'com.rigobert.rigobertSays.tip_large';

const _kAndroidTipS = 'tip_small';
const _kAndroidTipM = 'tip_medium';
const _kAndroidTipL = 'tip_large';

final kProductTipS = Platform.isIOS ? _kIosTipS : _kAndroidTipS;
final kProductTipM = Platform.isIOS ? _kIosTipM : _kAndroidTipM;
final kProductTipL = Platform.isIOS ? _kIosTipL : _kAndroidTipL;

final kAllProductIds = {kProductTipS, kProductTipM, kProductTipL};

// Ad-free time granted per tip tier, in calendar months. Tips stack: a new
// tip extends whatever ad-free time is left rather than replacing it.
final kAdFreeMonths = {
  kProductTipS: 1,
  kProductTipM: 3,
  kProductTipL: 12,
};

// Show tip prompt every N rounds, as long as ads aren't currently suppressed.
const kTipPromptEvery = 20;

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kHasTipped      = 'has_tipped'; // legacy flag, read once for migration
const _kAdsFreeUntilMs = 'ads_free_until_ms';
const _kRoundsPlayed   = 'rounds_played';

// ── PurchaseService ───────────────────────────────────────────────────────────

class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._();
  factory PurchaseService() => _instance;
  PurchaseService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available      = false;
  DateTime? _adsFreeUntil;
  int  _roundsPlayed   = 0;

  Map<String, ProductDetails> _products = {};
  bool _loadingPurchase = false;

  bool get available       => _available;
  int  get roundsPlayed    => _roundsPlayed;
  bool get loadingPurchase => _loadingPurchase;

  /// When the current ad-free period ends, or null if none is active.
  DateTime? get adsFreeUntil => _adsFreeUntil;

  /// True while a tip's ad-free period is still active.
  bool get adsRemoved =>
      _adsFreeUntil != null && _adsFreeUntil!.isAfter(DateTime.now());

  /// True when it's time to nudge the player for a tip.
  bool get shouldShowTipPrompt =>
      !adsRemoved && _roundsPlayed > 0 && _roundsPlayed % kTipPromptEvery == 0;

  ProductDetails? product(String id) => _products[id];

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _roundsPlayed = prefs.getInt(_kRoundsPlayed) ?? 0;

    final storedMs = prefs.getInt(_kAdsFreeUntilMs);
    if (storedMs != null) {
      _adsFreeUntil = DateTime.fromMillisecondsSinceEpoch(storedMs);
    } else if (prefs.getBool(_kHasTipped) ?? false) {
      // Migrate players who tipped under the old "ads removed forever"
      // scheme — grandfather them in rather than suddenly showing ads again.
      _adsFreeUntil = DateTime.now().add(const Duration(days: 365 * 100));
      await prefs.setInt(_kAdsFreeUntilMs, _adsFreeUntil!.millisecondsSinceEpoch);
    }

    _available = await _iap.isAvailable();
    if (!_available) { notifyListeners(); return; }

    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate);

    debugPrint('Querying product IDs: $kAllProductIds');
    try {
      final resp = await _iap.queryProductDetails(kAllProductIds);
      debugPrint('IAP query response: ${resp.productDetails.length} products found');
      for (final p in resp.productDetails) {
        debugPrint('IAP product found: ${p.id}');
      }
      if (resp.error != null) {
        debugPrint('IAP query error: ${resp.error}');
      }
      _products = {for (final p in resp.productDetails) p.id: p};
    } catch (e) {
      debugPrint('IAP query exception: $e');
      rethrow;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Round tracking ────────────────────────────────────────────────────────

  Future<void> incrementRounds() async {
    _roundsPlayed++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRoundsPlayed, _roundsPlayed);
    notifyListeners();
  }

  // ── Purchases ─────────────────────────────────────────────────────────────

  Future<void> buyTip(String productId) => _buy(productId);

  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  Future<void> _buy(String productId) async {
    final details = _products[productId];
    if (details == null) {
      debugPrint('IAP error: Product not found for ID: $productId');
      _loadingPurchase = false;
      notifyListeners();
      return;
    }
    
    _loadingPurchase = true;
    notifyListeners();
    
    try {
      final param = PurchaseParam(productDetails: details);
      await _iap.buyConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('IAP error during purchase: $e');
      rethrow;
    } finally {
      _loadingPurchase = false;
      notifyListeners();
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _grantAdFreeTime(p.productID);
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      } else if (p.status == PurchaseStatus.error) {
        // Provide more detailed error information
        debugPrint('IAP error: ${p.error}');
        debugPrint('IAP error code: ${p.error?.code}');
        debugPrint('IAP error message: ${p.error?.message}');
        debugPrint('IAP error details: ${p.error?.details}');
      }
    }
    _loadingPurchase = false;
    notifyListeners();
  }

  /// Extends the ad-free period by the tier's duration. Stacks on top of any
  /// remaining time rather than replacing it (buying while already ad-free
  /// pushes the expiry further out instead of wasting the earlier tip).
  Future<void> _grantAdFreeTime(String productId) async {
    final months = kAdFreeMonths[productId];
    if (months == null) return; // not a tip product (or unrecognised)

    final now = DateTime.now();
    final base = (_adsFreeUntil != null && _adsFreeUntil!.isAfter(now))
        ? _adsFreeUntil!
        : now;
    _adsFreeUntil = DateTime(
      base.year, base.month + months, base.day,
      base.hour, base.minute, base.second,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAdsFreeUntilMs, _adsFreeUntil!.millisecondsSinceEpoch);
  }
}
