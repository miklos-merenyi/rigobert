import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NoScreenshot.instance.screenshotOff();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const RigobertSaysApp());
}

class RigobertSaysApp extends StatelessWidget {
  const RigobertSaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rigobert Says',
      theme: ThemeData.dark(useMaterial3: true),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
