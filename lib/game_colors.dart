import 'package:flutter/material.dart';

enum GameColor { red, green, blue }

Color mixColors(Set<GameColor> colors) {
  final r = colors.contains(GameColor.red);
  final g = colors.contains(GameColor.green);
  final b = colors.contains(GameColor.blue);
  if (r && g && b) return Colors.white;
  if (r && g) return Colors.yellow;
  if (r && b) return const Color(0xFFFF00FF); // Magenta
  if (g && b) return const Color(0xFF00FFFF); // Cyan
  if (r) return const Color(0xFFFF3333);
  if (g) return const Color(0xFF33FF33);
  if (b) return const Color(0xFF3366FF);
  return Colors.transparent;
}

String colorName(Set<GameColor> colors) {
  final r = colors.contains(GameColor.red);
  final g = colors.contains(GameColor.green);
  final b = colors.contains(GameColor.blue);
  if (r && g && b) return 'WHITE';
  if (r && g) return 'YELLOW';
  if (r && b) return 'MAGENTA';
  if (g && b) return 'CYAN';
  if (r) return 'RED';
  if (g) return 'GREEN';
  if (b) return 'BLUE';
  return '';
}
