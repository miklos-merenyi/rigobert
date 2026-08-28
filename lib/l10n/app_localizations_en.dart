// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get startButton => 'START';

  @override
  String get tryAgainButton => 'TRY AGAIN';

  @override
  String get keepGoingButton => 'KEEP GOING';

  @override
  String get howToPlay => 'How to play';

  @override
  String get supportTheDev => '☕  Support the dev';

  @override
  String get viewLeaderboard => '🏆  View leaderboard';

  @override
  String get watchCarefully => 'Watch carefully…';

  @override
  String stepProgress(int current, int total) {
    return 'Step $current / $total';
  }

  @override
  String levelScore(int level, int score) {
    return 'Level $level   •   Score $score';
  }

  @override
  String get diffStill => 'STILL';

  @override
  String get diffFloat => 'FLOAT';

  @override
  String get diffSpin => 'SPIN';

  @override
  String get diffBoth => 'BOTH';

  @override
  String get settingsHeader => 'SETTINGS';

  @override
  String get leaderboardToggleTitle => 'Leaderboard';

  @override
  String get leaderboardToggleDesc =>
      'Submit personal records to the global leaderboard';

  @override
  String youReachedLevel(int level, int score) {
    return 'You reached level $level\nScore: $score';
  }

  @override
  String newRecordLine(String mode, int score) {
    return '🏆 New record for $mode mode: $score';
  }

  @override
  String modeRecordLine(String mode, int score) {
    return '$mode mode record: $score';
  }

  @override
  String modeLabel(String mode) {
    return '$mode mode';
  }

  @override
  String get timeoutMessage => 'You did not press any button in time';

  @override
  String wrongPressMessage(
    String pressed,
    String pressedComp,
    String expected,
    String expectedComp,
  ) {
    return 'You pressed $pressed ($pressedComp),\nbut $expected ($expectedComp) was expected';
  }

  @override
  String earlyReleaseMessage(String expected, String expectedComp) {
    return 'You released too early — $expected ($expectedComp) was expected';
  }

  @override
  String get signInDialogTitle => 'Sign in?';

  @override
  String get signInDialogBody =>
      'Leaderboards are powered by Game Center (iOS) or Play Games (Android). Sign in to view rankings — or skip if you\'d rather not.';

  @override
  String get skipButton => 'Skip';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInFailedMessage => 'Could not sign in — try again later.';

  @override
  String get submitLeaderboardTitle => 'Submit to leaderboard?';

  @override
  String get submitLeaderboardBody =>
      'You\'ve reached a score worth posting! Sign in with Play Games to submit it to the global leaderboard.';

  @override
  String get noThanksButton => 'No thanks';

  @override
  String get turnOffLeaderboardTitle => 'Turn off leaderboards?';

  @override
  String get turnOffLeaderboardBody =>
      'You can always re-enable leaderboards later from Settings.';

  @override
  String get keepOnButton => 'Keep on';

  @override
  String get turnOffButton => 'Turn off';

  @override
  String get leaderboardNotSubmittedOff => 'Not submitted — leaderboard off';

  @override
  String get leaderboardSubmitted => 'Submitted to leaderboard ✓';

  @override
  String get leaderboardNotSubmittedSignIn => 'Not submitted (sign in to rank)';

  @override
  String get screenshotTipHeader => '💡  Tip';

  @override
  String get screenshotTipBody =>
      'Some Android devices take a screenshot when you swipe with three fingers — which can accidentally interrupt the game.';

  @override
  String get screenshotTipSettings =>
      'You can disable this in Settings → Advanced features → Motions and gestures → Palm swipe to capture (or similar, depending on your device).';

  @override
  String get gotItButton => 'Got it';

  @override
  String get supportTitle => 'SUPPORT THE DEV';

  @override
  String get supportBody =>
      'Rigobert Says is free to play, with the occasional ad. A tip removes ads for a while and stops these popups too.';

  @override
  String get tipSmall => 'Small tip';

  @override
  String get tipMedium => 'Medium tip';

  @override
  String get tipLarge => 'Royal tip';

  @override
  String get tipSmallDuration => '1 month ad-free';

  @override
  String get tipMediumDuration => '3 months ad-free';

  @override
  String get tipLargeDuration => '1 year ad-free';

  @override
  String adsFreeUntilLabel(String date) {
    return 'Ads removed until $date';
  }

  @override
  String get tipNotTransferable =>
      'Ad-free time is tied to this device only — it can\'t be transferred to another device or account, and isn\'t restored if you reinstall.';

  @override
  String get notNowButton => 'Not now — keep playing';

  @override
  String get howToPlayTitle => 'HOW TO PLAY';

  @override
  String get howToBasicsTitle => 'The basics';

  @override
  String get howToBasicsBody =>
      'RIGOBERT SAYS is a memory game. The disc lights up a sequence of coloured buttons — watch carefully, then tap them back in the same order. Each round adds one more step.';

  @override
  String get howToButtonsTitle => 'The buttons';

  @override
  String get howToButtonsBody =>
      'There are three coloured segments on the disc:\n  🔴  Red\n  🟢  Green\n  🔵  Blue\n\nSome steps light up two or even all three at once — you must press those buttons simultaneously.';

  @override
  String get howToMixingTitle => 'Colour mixing';

  @override
  String get howToMixingBody =>
      'When multiple buttons light up together, the disc blends their colours:\n  🔴 + 🟢 = Yellow\n  🔴 + 🔵 = Magenta\n  🟢 + 🔵 = Cyan\n  🔴 + 🟢 + 🔵 = White';

  @override
  String get howToModesTitle => 'Difficulty modes';

  @override
  String get howToModesBody =>
      'Choose your challenge before you start:\n\n  STILL — the disc stays in the centre.\n  FLOAT — the disc drifts around the screen.\n  SPIN  — the disc slowly rotates.\n  BOTH  — the disc floats and spins at the same time.\n\nFloating and spinning speeds increase as the sequence grows longer.';

  @override
  String get howToScoringTitle => 'Scoring';

  @override
  String get howToScoringBody =>
      'You score points for every correct sequence. Your personal record is saved between sessions — can you beat it?';

  @override
  String get howToLeaderboardsTitle => 'Leaderboards';

  @override
  String get howToLeaderboardsBody =>
      'Every mode has its own global leaderboard — STILL, FLOAT, SPIN, and BOTH are ranked separately.\n\nScores are submitted automatically when you set a personal record of 10 or more. Leaderboards use Game Center on iOS and Play Games on Android. Signing in is completely optional — the game is fully playable without it.';

  @override
  String get colorRed => 'Red';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorMagenta => 'Magenta';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorWhite => 'White';

  @override
  String get legendRedGreen => 'Red + Green = Yellow';

  @override
  String get legendRedBlue => 'Red + Blue = Magenta';

  @override
  String get legendGreenBlue => 'Green + Blue = Cyan';

  @override
  String get legendAllThree => 'All three = White';
}
