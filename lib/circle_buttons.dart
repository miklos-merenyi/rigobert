import 'dart:math';
import 'dart:ui' as ui;
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
    final radius = min(size.width, size.height) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Drop shadow (drawn outside the clip) ──────────────────────────────
    canvas.drawCircle(
      center + const Offset(0, 6),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // ── Clip everything else to the circle ────────────────────────────────
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    final mixedColor = highlighted.isNotEmpty ? mixColors(highlighted) : null;

    for (final (color, baseColor, startAngle, labelAngle) in _sectors) {
      final isLit = highlighted.contains(color);
      final litColor = mixedColor ?? baseColor;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, 2 * pi / 3, false)
        ..close();

      // "Peak" – the point on the sector face where a dome would peak.
      // Placed at 62% of the radius along the sector's centre direction.
      final peak = center +
          Offset(cos(labelAngle), sin(labelAngle)) * radius * 0.62;

      // Dim base colour (12% brightness, derived without float-channel issues)
      final dimColor = Color.lerp(Colors.black, baseColor, 0.12)!;
      // Mid colour for dome gradient
      final midColor = Color.lerp(Colors.black, baseColor, 0.42)!;

      if (isLit) {
        // ── LIT / PRESSED ──────────────────────────────────────────────────

        // 1. Flat fill with lit (possibly mixed) colour
        canvas.drawPath(path, Paint()
          ..color = litColor
          ..style = PaintingStyle.fill);

        // 2. Inner shadow ring – simulates the button being pressed in
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.radial(
              peak,
              radius * 1.05,
              [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
              [0.25, 1.0],
            )
            ..style = PaintingStyle.fill,
        );

        // 3. Specular highlight – compact bright spot near the peak
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.radial(
              peak,
              radius * 0.28,
              [
                Colors.white.withValues(alpha: 0.60),
                Colors.transparent,
              ],
            )
            ..style = PaintingStyle.fill,
        );

        // 4. Outer glow (blurred, same colour)
        canvas.drawPath(
          path,
          Paint()
            ..color = litColor.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
            ..style = PaintingStyle.fill,
        );
      } else {
        // ── UNLIT / RAISED ─────────────────────────────────────────────────

        // 1. Dark base
        canvas.drawPath(path, Paint()
          ..color = dimColor
          ..style = PaintingStyle.fill);

        // 2. Dome gradient – brighter at the peak, fades to dim at edges
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.radial(
              peak,
              radius * 0.72,
              [midColor, dimColor],
            )
            ..style = PaintingStyle.fill,
        );

        // 3. Subtle specular – tiny bright spot suggesting a glossy surface
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.radial(
              peak,
              radius * 0.20,
              [Colors.white.withValues(alpha: 0.18), Colors.transparent],
            )
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── Groove dividers between sectors ───────────────────────────────────
    for (final a in [11 * pi / 6, pi / 2, 7 * pi / 6]) {
      final end = center + Offset(cos(a) * radius, sin(a) * radius);
      // Dark groove centre
      canvas.drawLine(center, end,
          Paint()..color = Colors.black..strokeWidth = 4..style = PaintingStyle.stroke);
      // Light bevel edge offset to one side of the groove
      final perp = Offset(cos(a + pi / 2), sin(a + pi / 2)) * 2.5;
      canvas.drawLine(center + perp, end + perp,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.12)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke);
    }

    canvas.restore();

    // ── Outer ring bevel ─────────────────────────────────────────────────
    // Dark outer shadow stroke
    canvas.drawCircle(center, radius + 1.5,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.60)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke);
    // Lighter inner highlight stroke
    canvas.drawCircle(center, radius - 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
    // Thin rim
    canvas.drawCircle(center, radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);

    // ── Centre hub – small 3-D sphere ─────────────────────────────────────
    final hubR = radius * 0.13;
    canvas.drawCircle(center, hubR, Paint()..color = const Color(0xFF1A1A1A));
    // Specular on hub: off-centre bright spot
    canvas.drawCircle(
      center, hubR,
      Paint()
        ..shader = ui.Gradient.radial(
          center + Offset(-hubR * 0.30, -hubR * 0.38),
          hubR * 1.1,
          [Colors.white.withValues(alpha: 0.40), Colors.transparent],
        ),
    );
    canvas.drawCircle(center, hubR,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);

    // ── Labels ────────────────────────────────────────────────────────────
    for (final (color, _, _, labelAngle) in _sectors) {
      final isLit = highlighted.contains(color);
      final pos = center + Offset(cos(labelAngle), sin(labelAngle)) * radius * 0.58;
      final label = switch (color) {
        GameColor.red   => 'RED',
        GameColor.green => 'GREEN',
        GameColor.blue  => 'BLUE',
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
