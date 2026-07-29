import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'game_screen.dart';
import 'purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
