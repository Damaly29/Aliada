import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'siren_icon.dart';

/// Botón central. En `idle` un toque abre "¿Qué peligro hay?" (con cuenta regresiva cancelable,
/// que evita falsos positivos). En `active` es la "X" lima que abre la cancelación con PIN.
class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.active, required this.onTrigger, required this.onCancelPress});
  final bool active;
  final VoidCallback onTrigger;
  final VoidCallback onCancelPress;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  bool _pressed = false;

  void _tap() {
    if (widget.active) {
      widget.onCancelPress();
    } else {
      HapticFeedback.heavyImpact();
      widget.onTrigger();
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 62.0, ring = 76.0;
    final active = widget.active;
    return Semantics(
      button: true,
      label: active ? 'Cancelar alerta' : 'Botón de alerta',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _tap,
        child: SizedBox(
          width: ring,
          height: ring,
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.9 : 1,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: active ? AppColors.lime : AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 3),
                  boxShadow: AppShadows.floating,
                ),
                alignment: Alignment.center,
                child: active
                    ? const Icon(Icons.close_rounded, size: 30, color: AppColors.limeText)
                    : const SirenIcon(size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
