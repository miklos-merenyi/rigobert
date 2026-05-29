import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Product IDs ───────────────────────────────────────────────────────────────
// Register these exact IDs in App Store Connect / Google Play Console.
const kProductTipS = 'com.rigobert.rigobertSays.tip_small';   // ~$0.99
const kProductTipM = 'com.rigobert.rigobertSays.tip_medium';  // ~$2.99
const kProductTipL = 'com.rigobert.rigobertSays.tip_large';   // ~$4.99

const kAllProductIds = {kProductTipS, kProductTipM, kProductTipL};

// Show tip prompt every N rounds (as long as the player hasn't tipped).
const kTipPromptEvery = 20;

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kHasTipped    = 'has_tipped';
const _kRoundsPlayed = 'rounds_played';

// ── PurchaseService ───────────────────────────────────────────────────────────

class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._();
  factory PurchaseService() => _instance;
  PurchaseService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available      = false;
  bool _hasTipped      = false;
  int  _roundsPlayed   = 0;

  Map<String, ProductDetails> _products = {};
  bool _loadingPurchase = false;

  bool get available       => _available;
  bool get hasTipped       => _hasTipped;
  int  get roundsPlayed    => _roundsPlayed;
  bool get loadingPurchase => _loadingPurchase;

  /// True when it's time to nudge the player for a tip.
  bool get shouldShowTipPrompt =>
      !_hasTipped && _roundsPlayed > 0 && _roundsPlayed % kTipPromptEvery == 0;

  ProductDetails? product(String id) => _products[id];

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hasTipped    = prefs.getBool(_kHasTipped)    ?? false;
    _roundsPlayed = prefs.getInt(_kRoundsPlayed)  ?? 0;

    _available = await _iap.isAvailable();
    if (!_available) { notifyListeners(); return; }

    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate);

    final resp = await _iap.queryProductDetails(kAllProductIds);
    _products = {for (final p in resp.productDetails) p.id: p};
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
    if (details == null) return;
    _loadingPurchase = true;
    notifyListeners();
    final param = PurchaseParam(productDetails: details);
    await _iap.buyConsumable(purchaseParam: param);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        // Any tip silences future prompts.
        await _grantTipped();
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      } else if (p.status == PurchaseStatus.error) {
        debugPrint('IAP error: ${p.error}');
      }
    }
    _loadingPurchase = false;
    notifyListeners();
  }

  Future<void> _grantTipped() async {
    _hasTipped = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasTipped, true);
  }
}
