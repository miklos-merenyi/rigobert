import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

// ── AnalyticsService ─────────────────────────────────────────────────────────
// Thin wrapper around Firebase Analytics. All calls are fire-and-forget and
// never throw — if Firebase isn't initialised the calls are silently skipped.

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  FirebaseAnalytics? _fa;

  void init() {
    try {
      _fa = FirebaseAnalytics.instance;
    } catch (e) {
      debugPrint('AnalyticsService: init failed ($e)');
    }
  }

  // ── Game events ───────────────────────────────────────────────────────────

  /// Called when the player taps START.
  Future<void> logGameStarted(String difficulty) async {
    try {
      await _fa?.logLevelStart(levelName: difficulty);
    } catch (e) {
      debugPrint('AnalyticsService: logGameStarted failed ($e)');
    }
  }

  /// Called at game over. [reason] is one of: wrong_press · early_release · timeout.
  Future<void> logGameOver({
    required String difficulty,
    required int score,
    required int level,
    required String reason,
  }) async {
    try {
      await _fa?.logEvent(
        name: 'game_over',
        parameters: {
          'difficulty': difficulty,
          'score':      score,
          'level':      level,
          'reason':     reason,
        },
      );
    } catch (e) {
      debugPrint('AnalyticsService: logGameOver failed ($e)');
    }
  }
}
