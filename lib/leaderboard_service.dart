import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

// ── Leaderboard IDs ───────────────────────────────────────────────────────────
// Register these in App Store Connect (Game Center) and Google Play Console.
// One leaderboard per difficulty mode.
const _kIosStill   = 'com.rigobert.rigobertSays.leaderboard_still';
const _kIosFloat   = 'com.rigobert.rigobertSays.leaderboard_float';
const _kIosSpin    = 'com.rigobert.rigobertSays.leaderboard_spin';
const _kIosBoth    = 'com.rigobert.rigobertSays.leaderboard_both';

const _kAndroidStill = 'CgkI_leaderboard_still';   // replace with Play Console IDs
const _kAndroidFloat = 'CgkI_leaderboard_float';
const _kAndroidSpin  = 'CgkI_leaderboard_spin';
const _kAndroidBoth  = 'CgkI_leaderboard_both';

// Minimum score worth posting to the global board.
const kLeaderboardMinScore = 10;

// ── LeaderboardService ────────────────────────────────────────────────────────

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._();
  factory LeaderboardService() => _instance;
  LeaderboardService._();

  bool _signedIn = false;
  bool get isSignedIn => _signedIn;

  // ── Sign-in ───────────────────────────────────────────────────────────────

  /// Called once at app start — silent, no UI shown on failure.
  Future<void> silentSignIn() async {
    try {
      await GamesServices.signIn();
      _signedIn = true;
    } catch (e) {
      // Not signed in — that's fine. We'll try interactively if the player
      // explicitly taps "View Leaderboard".
      debugPrint('LeaderboardService: silent sign-in skipped ($e)');
    }
  }

  /// Tries an interactive sign-in (shows the platform UI).
  /// Returns true if the player is now signed in.
  Future<bool> interactiveSignIn() async {
    try {
      await GamesServices.signIn();
      _signedIn = true;
    } catch (e) {
      debugPrint('LeaderboardService: interactive sign-in failed ($e)');
      _signedIn = false;
    }
    return _signedIn;
  }

  // ── Score submission ──────────────────────────────────────────────────────

  /// Submits [score] for [modeName] (one of: still, float, spin, both).
  /// Only posts if the player is signed in and score ≥ [kLeaderboardMinScore].
  Future<void> submitScore(String modeName, int score) async {
    if (!_signedIn) return;
    if (score < kLeaderboardMinScore) return;

    final ios     = _iosId(modeName);
    final android = _androidId(modeName);
    if (ios == null || android == null) return;

    try {
      await GamesServices.submitScore(
        score: Score(
          iOSLeaderboardID:     ios,
          androidLeaderboardID: android,
          value:                score,
        ),
      );
    } catch (e) {
      debugPrint('LeaderboardService: submitScore failed ($e)');
    }
  }

  // ── Show leaderboard ──────────────────────────────────────────────────────

  /// Opens the native leaderboard UI for [modeName].
  /// If not signed in, returns false so the caller can prompt politely.
  Future<bool> showLeaderboard(String modeName) async {
    if (!_signedIn) return false;

    final ios     = _iosId(modeName);
    final android = _androidId(modeName);
    if (ios == null || android == null) return false;

    try {
      await GamesServices.showLeaderboards(
        iOSLeaderboardID:     ios,
        androidLeaderboardID: android,
      );
      return true;
    } catch (e) {
      debugPrint('LeaderboardService: showLeaderboard failed ($e)');
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _iosId(String modeName) => switch (modeName.toLowerCase()) {
    'still' => _kIosStill,
    'float' => _kIosFloat,
    'spin'  => _kIosSpin,
    'both'  => _kIosBoth,
    _       => null,
  };

  String? _androidId(String modeName) => switch (modeName.toLowerCase()) {
    'still' => _kAndroidStill,
    'float' => _kAndroidFloat,
    'spin'  => _kAndroidSpin,
    'both'  => _kAndroidBoth,
    _       => null,
  };
}
