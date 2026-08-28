import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('hu'),
  ];

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get startButton;

  /// No description provided for @tryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get tryAgainButton;

  /// No description provided for @keepGoingButton.
  ///
  /// In en, this message translates to:
  /// **'KEEP GOING'**
  String get keepGoingButton;

  /// No description provided for @howToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlay;

  /// No description provided for @supportTheDev.
  ///
  /// In en, this message translates to:
  /// **'☕  Support the dev'**
  String get supportTheDev;

  /// No description provided for @viewLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'🏆  View leaderboard'**
  String get viewLeaderboard;

  /// No description provided for @watchCarefully.
  ///
  /// In en, this message translates to:
  /// **'Watch carefully…'**
  String get watchCarefully;

  /// No description provided for @stepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} / {total}'**
  String stepProgress(int current, int total);

  /// No description provided for @levelScore.
  ///
  /// In en, this message translates to:
  /// **'Level {level}   •   Score {score}'**
  String levelScore(int level, int score);

  /// No description provided for @diffStill.
  ///
  /// In en, this message translates to:
  /// **'STILL'**
  String get diffStill;

  /// No description provided for @diffFloat.
  ///
  /// In en, this message translates to:
  /// **'FLOAT'**
  String get diffFloat;

  /// No description provided for @diffSpin.
  ///
  /// In en, this message translates to:
  /// **'SPIN'**
  String get diffSpin;

  /// No description provided for @diffBoth.
  ///
  /// In en, this message translates to:
  /// **'BOTH'**
  String get diffBoth;

  /// No description provided for @settingsHeader.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsHeader;

  /// No description provided for @leaderboardToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardToggleTitle;

  /// No description provided for @leaderboardToggleDesc.
  ///
  /// In en, this message translates to:
  /// **'Submit personal records to the global leaderboard'**
  String get leaderboardToggleDesc;

  /// No description provided for @youReachedLevel.
  ///
  /// In en, this message translates to:
  /// **'You reached level {level}\nScore: {score}'**
  String youReachedLevel(int level, int score);

  /// No description provided for @newRecordLine.
  ///
  /// In en, this message translates to:
  /// **'🏆 New record for {mode} mode: {score}'**
  String newRecordLine(String mode, int score);

  /// No description provided for @modeRecordLine.
  ///
  /// In en, this message translates to:
  /// **'{mode} mode record: {score}'**
  String modeRecordLine(String mode, int score);

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'{mode} mode'**
  String modeLabel(String mode);

  /// No description provided for @timeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'You did not press any button in time'**
  String get timeoutMessage;

  /// No description provided for @wrongPressMessage.
  ///
  /// In en, this message translates to:
  /// **'You pressed {pressed} ({pressedComp}),\nbut {expected} ({expectedComp}) was expected'**
  String wrongPressMessage(
    String pressed,
    String pressedComp,
    String expected,
    String expectedComp,
  );

  /// No description provided for @earlyReleaseMessage.
  ///
  /// In en, this message translates to:
  /// **'You released too early — {expected} ({expectedComp}) was expected'**
  String earlyReleaseMessage(String expected, String expectedComp);

  /// No description provided for @signInDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in?'**
  String get signInDialogTitle;

  /// No description provided for @signInDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards are powered by Game Center (iOS) or Play Games (Android). Sign in to view rankings — or skip if you\'d rather not.'**
  String get signInDialogBody;

  /// No description provided for @skipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipButton;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @signInFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in — try again later.'**
  String get signInFailedMessage;

  /// No description provided for @submitLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit to leaderboard?'**
  String get submitLeaderboardTitle;

  /// No description provided for @submitLeaderboardBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached a score worth posting! Sign in with Play Games to submit it to the global leaderboard.'**
  String get submitLeaderboardBody;

  /// No description provided for @noThanksButton.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get noThanksButton;

  /// No description provided for @turnOffLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off leaderboards?'**
  String get turnOffLeaderboardTitle;

  /// No description provided for @turnOffLeaderboardBody.
  ///
  /// In en, this message translates to:
  /// **'You can always re-enable leaderboards later from Settings.'**
  String get turnOffLeaderboardBody;

  /// No description provided for @keepOnButton.
  ///
  /// In en, this message translates to:
  /// **'Keep on'**
  String get keepOnButton;

  /// No description provided for @turnOffButton.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOffButton;

  /// No description provided for @leaderboardNotSubmittedOff.
  ///
  /// In en, this message translates to:
  /// **'Not submitted — leaderboard off'**
  String get leaderboardNotSubmittedOff;

  /// No description provided for @leaderboardSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted to leaderboard ✓'**
  String get leaderboardSubmitted;

  /// No description provided for @leaderboardNotSubmittedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Not submitted (sign in to rank)'**
  String get leaderboardNotSubmittedSignIn;

  /// No description provided for @screenshotTipHeader.
  ///
  /// In en, this message translates to:
  /// **'💡  Tip'**
  String get screenshotTipHeader;

  /// No description provided for @screenshotTipBody.
  ///
  /// In en, this message translates to:
  /// **'Some Android devices take a screenshot when you swipe with three fingers — which can accidentally interrupt the game.'**
  String get screenshotTipBody;

  /// No description provided for @screenshotTipSettings.
  ///
  /// In en, this message translates to:
  /// **'You can disable this in Settings → Advanced features → Motions and gestures → Palm swipe to capture (or similar, depending on your device).'**
  String get screenshotTipSettings;

  /// No description provided for @gotItButton.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotItButton;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT THE DEV'**
  String get supportTitle;

  /// No description provided for @supportBody.
  ///
  /// In en, this message translates to:
  /// **'Rigobert Says is free to play, with the occasional ad. If you enjoy it, any tip removes ads for good and stops these popups too.'**
  String get supportBody;

  /// No description provided for @tipSmall.
  ///
  /// In en, this message translates to:
  /// **'Small tip'**
  String get tipSmall;

  /// No description provided for @tipMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium tip'**
  String get tipMedium;

  /// No description provided for @tipLarge.
  ///
  /// In en, this message translates to:
  /// **'Royal tip'**
  String get tipLarge;

  /// No description provided for @notNowButton.
  ///
  /// In en, this message translates to:
  /// **'Not now — keep playing'**
  String get notNowButton;

  /// No description provided for @howToPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'HOW TO PLAY'**
  String get howToPlayTitle;

  /// No description provided for @howToBasicsTitle.
  ///
  /// In en, this message translates to:
  /// **'The basics'**
  String get howToBasicsTitle;

  /// No description provided for @howToBasicsBody.
  ///
  /// In en, this message translates to:
  /// **'RIGOBERT SAYS is a memory game. The disc lights up a sequence of coloured buttons — watch carefully, then tap them back in the same order. Each round adds one more step.'**
  String get howToBasicsBody;

  /// No description provided for @howToButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'The buttons'**
  String get howToButtonsTitle;

  /// No description provided for @howToButtonsBody.
  ///
  /// In en, this message translates to:
  /// **'There are three coloured segments on the disc:\n  🔴  Red\n  🟢  Green\n  🔵  Blue\n\nSome steps light up two or even all three at once — you must press those buttons simultaneously.'**
  String get howToButtonsBody;

  /// No description provided for @howToMixingTitle.
  ///
  /// In en, this message translates to:
  /// **'Colour mixing'**
  String get howToMixingTitle;

  /// No description provided for @howToMixingBody.
  ///
  /// In en, this message translates to:
  /// **'When multiple buttons light up together, the disc blends their colours:\n  🔴 + 🟢 = Yellow\n  🔴 + 🔵 = Magenta\n  🟢 + 🔵 = Cyan\n  🔴 + 🟢 + 🔵 = White'**
  String get howToMixingBody;

  /// No description provided for @howToModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Difficulty modes'**
  String get howToModesTitle;

  /// No description provided for @howToModesBody.
  ///
  /// In en, this message translates to:
  /// **'Choose your challenge before you start:\n\n  STILL — the disc stays in the centre.\n  FLOAT — the disc drifts around the screen.\n  SPIN  — the disc slowly rotates.\n  BOTH  — the disc floats and spins at the same time.\n\nFloating and spinning speeds increase as the sequence grows longer.'**
  String get howToModesBody;

  /// No description provided for @howToScoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Scoring'**
  String get howToScoringTitle;

  /// No description provided for @howToScoringBody.
  ///
  /// In en, this message translates to:
  /// **'You score points for every correct sequence. Your personal record is saved between sessions — can you beat it?'**
  String get howToScoringBody;

  /// No description provided for @howToLeaderboardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get howToLeaderboardsTitle;

  /// No description provided for @howToLeaderboardsBody.
  ///
  /// In en, this message translates to:
  /// **'Every mode has its own global leaderboard — STILL, FLOAT, SPIN, and BOTH are ranked separately.\n\nScores are submitted automatically when you set a personal record of 10 or more. Leaderboards use Game Center on iOS and Play Games on Android. Signing in is completely optional — the game is fully playable without it.'**
  String get howToLeaderboardsBody;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorMagenta.
  ///
  /// In en, this message translates to:
  /// **'Magenta'**
  String get colorMagenta;

  /// No description provided for @colorCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get colorCyan;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @legendRedGreen.
  ///
  /// In en, this message translates to:
  /// **'Red + Green = Yellow'**
  String get legendRedGreen;

  /// No description provided for @legendRedBlue.
  ///
  /// In en, this message translates to:
  /// **'Red + Blue = Magenta'**
  String get legendRedBlue;

  /// No description provided for @legendGreenBlue.
  ///
  /// In en, this message translates to:
  /// **'Green + Blue = Cyan'**
  String get legendGreenBlue;

  /// No description provided for @legendAllThree.
  ///
  /// In en, this message translates to:
  /// **'All three = White'**
  String get legendAllThree;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
