import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'analytics_service.dart';
import 'l10n/app_localizations.dart';
import 'game_screen.dart';
import 'purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );
  AnalyticsService().init();
  await PurchaseService().init();
  runApp(const RigobertSaysApp());
}

class RigobertSaysApp extends StatelessWidget {
  const RigobertSaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rigobert Says',
      theme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
