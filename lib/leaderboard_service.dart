import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Leaderboard IDs ───────────────────────────────────────────────────────────
// Register these in App Store Connect (Game Center) and Google Play Console.
// One leaderboard per difficulty mode.
const _kIosStill   = 'com.rigobert.rigobertSays.leaderboard_still';
const _kIosFloat   = 'com.rigobert.rigobertSays.leaderboard_float';
const _kIosSpin    = 'com.rigobert.rigobertSays.leaderboard_spin';
const _kIosBoth    = 'com.rigobert.rigobertSays.leaderboard_both';

const _kAndroidStill = 'CgkIwuSWp_0SEAIQAg';   // replace with Play Console IDs
const _kAndroidFloat = 'CgkIwuSWp_0SEAIQAQ';
const _kAndroidSpin  = 'CgkIwuSWp_0SEAIQAw';
const _kAndroidBoth  = 'CgkIwuSWp_0SEAIQBA';

// Minimum score worth posting to the global board.
const kLeaderboardMinScore = 10;

// SharedPreferences key for the opt-out flag.
const kLeaderboardOptOutKey = 'leaderboard_opted_out';

// ── LeaderboardService ────────────────────────────────────────────────────────

class LeaderboardService extends ChangeNotifier {
  static final LeaderboardService _instance = LeaderboardService._();
  factory LeaderboardService() => _instance;
  LeaderboardService._();

  bool _signedIn   = false;
  bool _optedOut   = false;

  bool get isSignedIn  => _signedIn;
  bool get optedOut    => _optedOut;
  /// True when submission is active (signed in, not opted out).
  bool get isActive    => _signedIn && !_optedOut;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _optedOut = prefs.getBool(kLeaderboardOptOutKey) ?? false;
    notifyListeners();
  }

  // ── Opt-out ───────────────────────────────────────────────────────────────

  Future<void> setOptedOut(bool value) async {
    _optedOut = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLeaderboardOptOutKey, value);
    notifyListeners();
  }

  // ── Sign-in ───────────────────────────────────────────────────────────────

  /// Called once at app start — silent, no UI shown on failure.
  Future<void> silentSignIn() async {
    await loadPrefs();
    try {
      await GamesServices.signIn();
      _signedIn = true;
      notifyListeners();
    } catch (e) {
      debugPrint('LeaderboardService: silent sign-in skipped ($e)');
    }
  }

  /// Tries an interactive sign-in (shows the platform UI).
  /// Returns true if the player is now signed in.
  Future<bool> interactiveSignIn() async {
    try {
      await GamesServices.signIn();
      _signedIn = true;
      notifyListeners();
    } catch (e) {
      debugPrint('LeaderboardService: interactive sign-in failed ($e)');
      _signedIn = false;
    }
    return _signedIn;
  }

  // ── Score submission ──────────────────────────────────────────────────────

  /// Submits [score] for [modeName] (one of: still, float, spin, both).
  /// Returns true if the score was actually posted.
  /// Skipped silently if: opted out, not signed in, or score < [kLeaderboardMinScore].
  Future<bool> submitScore(String modeName, int score) async {
    if (_optedOut) return false;
    if (!_signedIn) return false;
    if (score < kLeaderboardMinScore) return false;

    final ios     = _iosId(modeName);
    final android = _androidId(modeName);
    if (ios == null || android == null) return false;

    try {
      await GamesServices.submitScore(
        score: Score(
          iOSLeaderboardID:     ios,
          androidLeaderboardID: android,
          value:                score,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('LeaderboardService: submitScore failed ($e)');
      return false;
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
