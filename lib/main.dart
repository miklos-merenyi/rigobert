import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const RugbartSaysApp());
}

class RugbartSaysApp extends StatelessWidget {
  const RugbartSaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rugbart Says',
      theme: ThemeData.dark(useMaterial3: true),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
