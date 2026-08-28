// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get startButton => 'COMENZAR';

  @override
  String get tryAgainButton => 'INTENTAR DE NUEVO';

  @override
  String get keepGoingButton => 'SEGUIR';

  @override
  String get howToPlay => 'Cómo jugar';

  @override
  String get supportTheDev => '☕  Apoya al desarrollador';

  @override
  String get viewLeaderboard => '🏆  Ver clasificación';

  @override
  String get watchCarefully => 'Observa atentamente…';

  @override
  String stepProgress(int current, int total) {
    return 'Paso $current / $total';
  }

  @override
  String levelScore(int level, int score) {
    return 'Nivel $level   •   Puntuación: $score';
  }

  @override
  String get diffStill => 'QUIETA';

  @override
  String get diffFloat => 'FLOTA';

  @override
  String get diffSpin => 'GIRA';

  @override
  String get diffBoth => 'AMBAS';

  @override
  String get settingsHeader => 'AJUSTES';

  @override
  String get leaderboardToggleTitle => 'Clasificación';

  @override
  String get leaderboardToggleDesc =>
      'Envía tus récords personales a la clasificación global';

  @override
  String youReachedLevel(int level, int score) {
    return 'Alcanzaste el nivel $level\nPuntuación: $score';
  }

  @override
  String newRecordLine(String mode, int score) {
    return '🏆 Nuevo récord en modo $mode: $score';
  }

  @override
  String modeRecordLine(String mode, int score) {
    return 'Récord del modo $mode: $score';
  }

  @override
  String modeLabel(String mode) {
    return 'modo $mode';
  }

  @override
  String get timeoutMessage => 'No pulsaste ningún botón a tiempo';

  @override
  String wrongPressMessage(
    String pressed,
    String pressedComp,
    String expected,
    String expectedComp,
  ) {
    return 'Pulsaste $pressed ($pressedComp),\npero se esperaba $expected ($expectedComp)';
  }

  @override
  String earlyReleaseMessage(String expected, String expectedComp) {
    return 'Soltaste demasiado pronto — se esperaba $expected ($expectedComp)';
  }

  @override
  String get signInDialogTitle => '¿Iniciar sesión?';

  @override
  String get signInDialogBody =>
      'Las clasificaciones funcionan con Game Center (iOS) o Play Games (Android). Inicia sesión para ver los rankings — o sáltalo si prefieres.';

  @override
  String get skipButton => 'Omitir';

  @override
  String get signInButton => 'Iniciar sesión';

  @override
  String get signInFailedMessage =>
      'No se pudo iniciar sesión — inténtalo más tarde.';

  @override
  String get submitLeaderboardTitle => '¿Enviar a la clasificación?';

  @override
  String get submitLeaderboardBody =>
      '¡Has alcanzado una puntuación digna de publicar! Inicia sesión con Play Games para enviarla a la clasificación global.';

  @override
  String get noThanksButton => 'No, gracias';

  @override
  String get turnOffLeaderboardTitle => '¿Desactivar clasificaciones?';

  @override
  String get turnOffLeaderboardBody =>
      'Puedes volver a activar las clasificaciones desde Ajustes.';

  @override
  String get keepOnButton => 'Mantener';

  @override
  String get turnOffButton => 'Desactivar';

  @override
  String get leaderboardNotSubmittedOff =>
      'No enviado — clasificación desactivada';

  @override
  String get leaderboardSubmitted => 'Enviado a la clasificación ✓';

  @override
  String get leaderboardNotSubmittedSignIn =>
      'No enviado (inicia sesión para clasificarte)';

  @override
  String get screenshotTipHeader => '💡  Consejo';

  @override
  String get screenshotTipBody =>
      'Algunos dispositivos Android hacen una captura cuando deslizas con tres dedos — lo que puede interrumpir accidentalmente el juego.';

  @override
  String get screenshotTipSettings =>
      'Puedes desactivarlo en Ajustes → Funciones avanzadas → Movimientos y gestos → Captura al deslizar la palma (o similar, según tu dispositivo).';

  @override
  String get gotItButton => 'Entendido';

  @override
  String get supportTitle => 'APOYA AL DESARROLLADOR';

  @override
  String get supportBody =>
      'Rigobert Says es gratis, con algún anuncio ocasional. Si te gusta, cualquier propina elimina los anuncios para siempre y también detiene estos mensajes.';

  @override
  String get tipSmall => 'Propina pequeña';

  @override
  String get tipMedium => 'Propina mediana';

  @override
  String get tipLarge => 'Propina real';

  @override
  String get notNowButton => 'Ahora no — seguir jugando';

  @override
  String get howToPlayTitle => 'CÓMO JUGAR';

  @override
  String get howToBasicsTitle => 'Lo básico';

  @override
  String get howToBasicsBody =>
      'RIGOBERT SAYS es un juego de memoria. El disco ilumina una secuencia de botones de colores — observa con atención y repítela en el mismo orden. Cada ronda añade un paso más.';

  @override
  String get howToButtonsTitle => 'Los botones';

  @override
  String get howToButtonsBody =>
      'El disco tiene tres segmentos de colores:\n  🔴  Rojo\n  🟢  Verde\n  🔵  Azul\n\nAlgunos pasos iluminan dos o incluso los tres a la vez — debes pulsarlos simultáneamente.';

  @override
  String get howToMixingTitle => 'Mezcla de colores';

  @override
  String get howToMixingBody =>
      'Cuando varios botones se iluminan juntos, el disco mezcla sus colores:\n  🔴 + 🟢 = Amarillo\n  🔴 + 🔵 = Magenta\n  🟢 + 🔵 = Cian\n  🔴 + 🟢 + 🔵 = Blanco';

  @override
  String get howToModesTitle => 'Modos de dificultad';

  @override
  String get howToModesBody =>
      'Elige tu desafío antes de empezar:\n\n  QUIETA — el disco permanece en el centro.\n  FLOTA  — el disco se desplaza por la pantalla.\n  GIRA   — el disco rota lentamente.\n  AMBAS  — el disco flota y gira a la vez.\n\nLa velocidad aumenta conforme crece la secuencia.';

  @override
  String get howToScoringTitle => 'Puntuación';

  @override
  String get howToScoringBody =>
      'Ganas puntos por cada secuencia correcta. Tu récord personal se guarda entre sesiones — ¿puedes superarlo?';

  @override
  String get howToLeaderboardsTitle => 'Clasificaciones';

  @override
  String get howToLeaderboardsBody =>
      'Cada modo tiene su propia clasificación global — QUIETA, FLOTA, GIRA y AMBAS se clasifican por separado.\n\nLas puntuaciones se envían automáticamente cuando superas tu récord con 10 o más puntos. Las clasificaciones usan Game Center en iOS y Play Games en Android. Iniciar sesión es completamente opcional — el juego es totalmente jugable sin ello.';

  @override
  String get colorRed => 'Rojo';

  @override
  String get colorGreen => 'Verde';

  @override
  String get colorBlue => 'Azul';

  @override
  String get colorYellow => 'Amarillo';

  @override
  String get colorMagenta => 'Magenta';

  @override
  String get colorCyan => 'Cian';

  @override
  String get colorWhite => 'Blanco';

  @override
  String get legendRedGreen => 'Rojo + Verde = Amarillo';

  @override
  String get legendRedBlue => 'Rojo + Azul = Magenta';

  @override
  String get legendGreenBlue => 'Verde + Azul = Cian';

  @override
  String get legendAllThree => 'Los tres = Blanco';
}
