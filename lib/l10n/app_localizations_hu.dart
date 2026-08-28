// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get startButton => 'KEZDÉS';

  @override
  String get tryAgainButton => 'ÚJRA';

  @override
  String get keepGoingButton => 'TOVÁBB';

  @override
  String get howToPlay => 'Hogyan kell játszani';

  @override
  String get supportTheDev => '☕  Támogasd a fejlesztőt';

  @override
  String get viewLeaderboard => '🏆  Ranglista';

  @override
  String get watchCarefully => 'Figyelj jól…';

  @override
  String stepProgress(int current, int total) {
    return '$current. lépés / $total';
  }

  @override
  String levelScore(int level, int score) {
    return '$level. szint   •   Pontszám: $score';
  }

  @override
  String get diffStill => 'ÁLLÓ';

  @override
  String get diffFloat => 'LEBEG';

  @override
  String get diffSpin => 'FOROG';

  @override
  String get diffBoth => 'VEGYES';

  @override
  String get settingsHeader => 'BEÁLLÍTÁSOK';

  @override
  String get leaderboardToggleTitle => 'Ranglista';

  @override
  String get leaderboardToggleDesc =>
      'Személyes rekordok küldése a globális ranglistára';

  @override
  String youReachedLevel(int level, int score) {
    return 'Elérted a $level. szintet\nPontszám: $score';
  }

  @override
  String newRecordLine(String mode, int score) {
    return '🏆 Új rekord $mode módban: $score';
  }

  @override
  String modeRecordLine(String mode, int score) {
    return '$mode módban elért rekord: $score';
  }

  @override
  String modeLabel(String mode) {
    return '$mode mód';
  }

  @override
  String get timeoutMessage => 'Nem nyomtál meg egyetlen gombot sem időben';

  @override
  String wrongPressMessage(
    String pressed,
    String pressedComp,
    String expected,
    String expectedComp,
  ) {
    return '$pressed ($pressedComp) gombot nyomtad meg,\nde $expected ($expectedComp) kellett volna';
  }

  @override
  String earlyReleaseMessage(String expected, String expectedComp) {
    return 'Túl korán engedted el — $expected ($expectedComp) kellett volna';
  }

  @override
  String get signInDialogTitle => 'Bejelentkezés?';

  @override
  String get signInDialogBody =>
      'A ranglistákat a Game Center (iOS) vagy a Play Games (Android) működteti. Jelentkezz be a rangsorok megtekintéséhez — vagy hagyd ki, ha nem szeretnéd.';

  @override
  String get skipButton => 'Kihagyás';

  @override
  String get signInButton => 'Bejelentkezés';

  @override
  String get signInFailedMessage =>
      'Nem sikerült bejelentkezni — próbáld meg később.';

  @override
  String get submitLeaderboardTitle => 'Feltöltés a ranglistára?';

  @override
  String get submitLeaderboardBody =>
      'Elértél egy ranglistára méltó pontszámot! Jelentkezz be a Play Games-szel, hogy feltöltsd a globális ranglistára.';

  @override
  String get noThanksButton => 'Nem, köszönöm';

  @override
  String get turnOffLeaderboardTitle => 'Kikapcsoljuk a ranglistákat?';

  @override
  String get turnOffLeaderboardBody =>
      'A ranglistákat bármikor újra bekapcsolhatod a Beállításokban.';

  @override
  String get keepOnButton => 'Maradjon be';

  @override
  String get turnOffButton => 'Kikapcsolás';

  @override
  String get leaderboardNotSubmittedOff => 'Nem küldve — ranglista kikapcsolva';

  @override
  String get leaderboardSubmitted => 'Feltöltve a ranglistára ✓';

  @override
  String get leaderboardNotSubmittedSignIn =>
      'Nem küldve (jelentkezz be a rangsorhoz)';

  @override
  String get screenshotTipHeader => '💡  Tipp';

  @override
  String get screenshotTipBody =>
      'Egyes Android eszközök képernyőképet készítenek, ha három ujjal húzol — ami véletlenül megszakíthatja a játékot.';

  @override
  String get screenshotTipSettings =>
      'Letilthatod a Beállítások → Speciális funkciók → Mozgások és kézmozdulatok → Tenyérrel csúsztatva rögzítés lehetőségnél (vagy hasonlónál, az eszköztől függően).';

  @override
  String get gotItButton => 'Értettem';

  @override
  String get supportTitle => 'TÁMOGASD A FEJLESZTŐT';

  @override
  String get supportBody =>
      'A Rigobert Says ingyenes, néha hirdetéssel. Ha élvezed, bármilyen támogatás végleg eltávolítja a hirdetéseket, és megszünteti ezeket az üzeneteket is.';

  @override
  String get tipSmall => 'Kis összeg';

  @override
  String get tipMedium => 'Közepes összeg';

  @override
  String get tipLarge => 'Nagyvonalú összeg';

  @override
  String get notNowButton => 'Nem most — játszom tovább';

  @override
  String get howToPlayTitle => 'HOGYAN KELL JÁTSZANI';

  @override
  String get howToBasicsTitle => 'Az alapok';

  @override
  String get howToBasicsBody =>
      'A RIGOBERT SAYS egy memóriajáték. A korong felvillan egy gombosorozatot — figyelj jól, majd érintsd meg őket ugyanabban a sorrendben. Minden körben egy lépéssel bővül a sorozat.';

  @override
  String get howToButtonsTitle => 'A gombok';

  @override
  String get howToButtonsBody =>
      'A korongon három színes szegmens van:\n  🔴  Piros\n  🟢  Zöld\n  🔵  Kék\n\nNéhány lépésnél egyszerre kettő vagy akár mindhárom felvillan — ezeket egyszerre kell megérinteni.';

  @override
  String get howToMixingTitle => 'Színkeverés';

  @override
  String get howToMixingBody =>
      'Ha több gomb egyszerre világít, a korong keveri a színeiket:\n  🔴 + 🟢 = Sárga\n  🔴 + 🔵 = Magenta\n  🟢 + 🔵 = Cián\n  🔴 + 🟢 + 🔵 = Fehér';

  @override
  String get howToModesTitle => 'Nehézségi módok';

  @override
  String get howToModesBody =>
      'Válaszd ki a kihívásodat a kezdés előtt:\n\n  ÁLLÓ   — a korong a középen marad.\n  LEBEG  — a korong úszik a képernyőn.\n  FOROG  — a korong lassan forog.\n  VEGYES — a korong lebeg és forog egyszerre.\n\nA sebességek nőnek, ahogy a sorozat hosszabbodik.';

  @override
  String get howToScoringTitle => 'Pontszámítás';

  @override
  String get howToScoringBody =>
      'Minden helyes sorozatért pontokat kapsz. A személyes rekordod megmarad a munkamenetek között — meg tudod dönteni?';

  @override
  String get howToLeaderboardsTitle => 'Ranglisták';

  @override
  String get howToLeaderboardsBody =>
      'Minden módnak van saját globális ranglistája — ÁLLÓ, LEBEG, FOROG és VEGYES külön vannak rangsorolva.\n\nA pontszámok automatikusan elküldésre kerülnek, ha 10 vagy több ponttal személyes rekordot állítasz be. A ranglisták iOS-en a Game Centert, Androidon a Play Gamest használják. A bejelentkezés teljesen opcionális — a játék bejelentkezés nélkül is teljes mértékben játszható.';

  @override
  String get colorRed => 'Piros';

  @override
  String get colorGreen => 'Zöld';

  @override
  String get colorBlue => 'Kék';

  @override
  String get colorYellow => 'Sárga';

  @override
  String get colorMagenta => 'Magenta';

  @override
  String get colorCyan => 'Cián';

  @override
  String get colorWhite => 'Fehér';

  @override
  String get legendRedGreen => 'Piros + Zöld = Sárga';

  @override
  String get legendRedBlue => 'Piros + Kék = Magenta';

  @override
  String get legendGreenBlue => 'Zöld + Kék = Cián';

  @override
  String get legendAllThree => 'Mindhárom = Fehér';
}
