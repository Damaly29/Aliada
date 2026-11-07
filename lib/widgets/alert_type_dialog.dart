import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum AlertChoice { emergency, companion, cancel }

/// Modal "¿Qué peligro hay?" (Figma "Alerta"). Si nadie responde antes de que termine
/// la cuenta regresiva, se envía la alerta de emergencia (por si ella no puede tocar la pantalla).
Future<AlertChoice> showAlertTypeDialog(BuildContext context, {Duration countdown = const Duration(seconds: 30)}) async {
  final r = await showGeneralDialog<AlertChoice>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _AlertTypeDialog(countdown: countdown),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
    ),
  );
  return r ?? AlertChoice.cancel;
}

class _AlertTypeDialog extends StatefulWidget {
  const _AlertTypeDialog({required this.countdown});
  final Duration countdown;
  @override
  State<_AlertTypeDialog> createState() => _AlertTypeDialogState();
}

class _AlertTypeDialogState extends State<_AlertTypeDialog> {
  late final DateTime _end = DateTime.now().add(widget.countdown);
  late Duration _left = widget.countdown;
  Timer? _timer;
  int _lastSecond = -1;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final left = _end.difference(DateTime.now());
      if (left <= Duration.zero) {
        _finish(AlertChoice.emergency);
        return;
      }
      if (left.inSeconds != _lastSecond) {
        _lastSecond = left.inSeconds;
        HapticFeedback.selectionClick();
      }
      setState(() => _left = left);
    });
  }

  void _finish(AlertChoice c) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    if (c != AlertChoice.cancel) HapticFeedback.heavyImpact();
    Navigator.of(context).pop(c);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = _left.inMinutes.toString().padLeft(2, '0');
    final s = (_left.inSeconds % 60).toString().padLeft(2, '0');
    final cs = ((_left.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  @override
  Widget build(BuildContext context) {
    Widget option(String label, Gradient? gradient, Color bg, Color fg, AlertChoice c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient,
                color: gradient == null ? bg : null,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: gradient == null ? null : AppShadows.soft,
              ),
              child: TextButton(
                onPressed: () => _finish(c),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: fg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3),
                ),
                child: Text(label),
              ),
            ),
          ),
        );

    final progress = (widget.countdown.inMilliseconds == 0)
        ? 0.0
        : (_left.inMilliseconds / widget.countdown.inMilliseconds).clamp(0.0, 1.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.fromLTRB(18, 40, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.floating,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('¿Qué peligro hay?', style: AppText.h2.copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                Text('Elige cómo te sientes ahora', style: AppText.caption.copyWith(fontSize: 12)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMist,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _clock,
                    style: const TextStyle(
                      fontFamily: AppFonts.title,
                      fontWeight: FontWeight.w700,
                      fontSize: 42,
                      letterSpacing: -1,
                      color: AppColors.text,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.primarySoft,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                option('ACOSO, NECESITO AYUDA', const LinearGradient(colors: [Color(0xFFE95145), Color(0xFFC92B20)]), AppColors.alertRed, Colors.white, AlertChoice.emergency),
                option('ADVERTENCIA DE POSIBLE ACOSO', null, AppColors.alertYellow, AppColors.alertBlack, AlertChoice.companion),
                option('CANCELAR ALARMA', null, AppColors.primaryMist, AppColors.textSoft, AlertChoice.cancel),
                const SizedBox(height: 2),
                Text(
                  'Si no eliges nada, enviaremos la alerta de emergencia al terminar el tiempo.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(fontSize: 11.5, height: 1.4),
                ),
              ]),
            ),
            GestureDetector(
              onTap: () => _finish(AlertChoice.cancel),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: AppShadows.soft,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 21),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
