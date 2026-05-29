import 'package:flutter/material.dart';

class ColorButton extends StatelessWidget {
  final String label;
  final Color activeColor;
  final bool isPressed;
  final bool enabled;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const ColorButton({
    super.key,
    required this.label,
    required this.activeColor,
    required this.isPressed,
    required this.enabled,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor =
        isPressed ? activeColor : activeColor.withValues(alpha: 0.22);

    return Expanded(
      child: Listener(
        onPointerDown: enabled ? (_) => onDown() : null,
        onPointerUp: enabled ? (_) => onUp() : null,
        onPointerCancel: enabled ? (_) => onUp() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: displayColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isPressed
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.55),
                      blurRadius: 24,
                      spreadRadius: 6,
                    )
                  ]
                : [],
          ),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
