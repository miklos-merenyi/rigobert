import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'game_colors.dart';

// Sector layout (all angles in Flutter canvas convention: 0=right/3 o'clock, CW):
//
//   Red   — arc start 7π/6 (210°), center at 3π/2 (270° = top)
//   Green — arc start 11π/6 (330°), center at π/6 (30° = bottom-right)
//   Blue  — arc start π/2 (90°),  center at 5π/6 (150° = bottom-left)
//
// Each sector sweeps 2π/3 (120°).

class CircleButtons extends StatefulWidget {
  final Set<GameColor> highlighted;
  final bool enabled;
  final void Function(GameColor) onDown;
  final void Function(GameColor) onUp;

  const CircleButtons({
    super.key,
    required this.highlighted,
    required this.enabled,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<CircleButtons> createState() => _CircleButtonsState();
}

class _CircleButtonsState extends State<CircleButtons> {
  final Map<int, GameColor> _pointerSectors = {};
  Size _size = Size.zero;

  GameColor? _sectorAt(Offset pos) {
    if (_size == Size.zero) return null;
    final cx = _size.width / 2;
    final cy = _size.height / 2;
    final r = min(_size.width, _size.height) / 2;
    final dx = pos.dx - cx;
    final dy = pos.dy - cy;
    if (dx * dx + dy * dy > r * r) return null;

    // Clockwise angle from 12 o'clock, [0, 360)
    double a = atan2(dx, -dy) * 180 / pi;
    if (a < 0) a += 360;

    // Red: top sector, covers 300°–360° and 0°–60°
    if (a < 60 || a >= 300) return GameColor.red;
    // Green: bottom-right, 60°–180°
    if (a < 180) return GameColor.green;
    // Blue: bottom-left, 180°–300°
    return GameColor.blue;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      return Listener(
        onPointerDown: (e) {
          if (!widget.enabled) return;
          final sector = _sectorAt(e.localPosition);
          if (sector != null && !_pointerSectors.containsValue(sector)) {
            _pointerSectors[e.pointer] = sector;
            widget.onDown(sector);
          }
        },
        onPointerUp: (e) {
          final sector = _pointerSectors.remove(e.pointer);
          if (sector != null) widget.onUp(sector);
        },
        onPointerCancel: (e) {
          final sector = _pointerSectors.remove(e.pointer);
          if (sector != null) widget.onUp(sector);
        },
        child: CustomPaint(
          size: _size,
          painter: _CirclePainter(highlighted: widget.highlighted),
        ),
      );
    });
  }
}

class _CirclePainter extends CustomPainter {
  final Set<GameColor> highlighted;

  const _CirclePainter({required this.highlighted});

  static final _sectors = [
    (GameColor.red,   const Color(0xFFFF3333), 7 * pi / 6,  3 * pi / 2),
    (GameColor.green, const Color(0xFF33FF44), 11 * pi / 6, pi / 6),
    (GameColor.blue,  const Color(0xFF3366FF), pi / 2,       5 * pi / 6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Clip all drawing to the circle boundary
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // When multiple buttons are active, all lit sectors show the blended colour
    final mixedColor = highlighted.isNotEmpty ? mixColors(highlighted) : null;

    // Draw sector fills
    for (final (color, baseColor, startAngle, _) in _sectors) {
      final isLit = highlighted.contains(color);
      final litColor = mixedColor ?? baseColor;
      final fillColor = isLit
          ? litColor
          : Color.fromRGBO(
              (baseColor.r * 0.15).round(),
              (baseColor.g * 0.15).round(),
              (baseColor.b * 0.15).round(),
              1.0,
            );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, 2 * pi / 3, false)
        ..close();

      canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);

      if (isLit) {
        // Soft inner glow using the blended colour
        canvas.drawPath(
          path,
          Paint()
            ..color = litColor.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Dividing radii between sectors
    // Boundary angles in Flutter canvas radians: 11π/6, π/2, 7π/6
    final divider = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final a in [11 * pi / 6, pi / 2, 7 * pi / 6]) {
      canvas.drawLine(
        center,
        center + Offset(cos(a) * radius, sin(a) * radius),
        divider,
      );
    }

    canvas.restore();

    // Outer ring border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // Centre hub
    canvas.drawCircle(center, radius * 0.13, Paint()..color = Colors.black);
    canvas.drawCircle(
      center,
      radius * 0.13,
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Labels
    for (final (color, _, _, labelAngle) in _sectors) {
      final isLit = highlighted.contains(color);
      final pos = center + Offset(cos(labelAngle), sin(labelAngle)) * radius * 0.58;
      final label = switch (color) {
        GameColor.red => 'RED',
        GameColor.green => 'GREEN',
        GameColor.blue => 'BLUE',
      };
      _paintLabel(canvas, label, pos, radius, isLit ? Colors.white : Colors.white38);
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset pos, double radius, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: radius * 0.16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CirclePainter old) => !setEquals(old.highlighted, highlighted);
}
