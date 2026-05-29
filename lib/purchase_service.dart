import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Product IDs ───────────────────────────────────────────────────────────────
// Register these exact IDs in App Store Connect / Google Play Console.
const kProductUnlock = 'com.rigobert.rigobertSays.unlock_hard';
const kProductTipS   = 'com.rigobert.rigobertSays.tip_small';   // ~$0.99
const kProductTipM   = 'com.rigobert.rigobertSays.tip_medium';  // ~$2.99
const kProductTipL   = 'com.rigobert.rigobertSays.tip_large';   // ~$4.99

const kAllProductIds = {kProductUnlock, kProductTipS, kProductTipM, kProductTipL};

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kUnlocked     = 'hard_mode_unlocked';
const _kTrialsUsed   = 'hard_mode_trials_used';
const kFreeTrials    = 3;

// ── PurchaseService ───────────────────────────────────────────────────────────

class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._();
  factory PurchaseService() => _instance;
  PurchaseService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available   = false;
  bool _unlocked    = false;
  int  _trialsUsed  = 0;

  Map<String, ProductDetails> _products = {};
  bool _loadingPurchase = false;

  bool get available      => _available;
  bool get unlocked       => _unlocked;
  bool get loadingPurchase => _loadingPurchase;
  int  get trialsUsed     => _trialsUsed;
  int  get trialsLeft     => (kFreeTrials - _trialsUsed).clamp(0, kFreeTrials);
  bool get hasTrialsLeft  => trialsLeft > 0;
  bool get canPlayHard    => _unlocked || hasTrialsLeft;

  ProductDetails? product(String id) => _products[id];

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _unlocked   = prefs.getBool(_kUnlocked)   ?? false;
    _trialsUsed = prefs.getInt(_kTrialsUsed)  ?? 0;

    _available = await _iap.isAvailable();
    if (!_available) { notifyListeners(); return; }

    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate);

    // Restore any previous purchases silently on startup.
    await _iap.restorePurchases();

    final resp = await _iap.queryProductDetails(kAllProductIds);
    _products = {for (final p in resp.productDetails) p.id: p};
    notifyListeners();
  }

  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Trial tracking ────────────────────────────────────────────────────────

  Future<void> consumeTrial() async {
    if (_unlocked) return;
    _trialsUsed++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTrialsUsed, _trialsUsed);
    notifyListeners();
  }

  // ── Purchases ─────────────────────────────────────────────────────────────

  Future<void> buyUnlock() => _buy(kProductUnlock);
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
    // Non-consumable for unlock; consumable for tips.
    if (productId == kProductUnlock) {
      await _iap.buyNonConsumable(purchaseParam: param);
    } else {
      await _iap.buyConsumable(purchaseParam: param);
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == kProductUnlock) {
          await _grantUnlock();
        }
        // Tips: nothing to grant — just complete the transaction.
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

  Future<void> _grantUnlock() async {
    _unlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUnlocked, true);
  }
}
