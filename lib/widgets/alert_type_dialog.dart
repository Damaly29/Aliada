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
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _AlertTypeDialog(countdown: countdown),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)), child: child),
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
    Widget option(String label, Color bg, Color fg, AlertChoice c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: () => _finish(c),
              style: TextButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: fg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2),
              ),
              child: Text(label),
            ),
          ),
        );

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Container(
              margin: const EdgeInsets.only(top: 22),
              padding: const EdgeInsets.fromLTRB(14, 40, 14, 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('¿Qué peligro hay?',
                    style: TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.primary)),
                const SizedBox(height: 12),
                Text(_clock,
                    style: const TextStyle(
                        fontFamily: AppFonts.title, fontSize: 44, color: AppColors.alertBlack, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 8),
                const Divider(color: AppColors.border),
                const SizedBox(height: 10),
                const Text('Selecciona según tu situación:',
                    style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                const SizedBox(height: 14),
                option('ACOSO, NECESITO AYUDA', AppColors.alertRed, Colors.white, AlertChoice.emergency),
                option('ADVERTENCIA DE POSIBLE ACOSO', AppColors.alertYellow, AppColors.alertBlack, AlertChoice.companion),
                option('CANCELAR ALARMA', AppColors.alertBlack, Colors.white, AlertChoice.cancel),
                const Text('Si no eliges nada, enviaremos la alerta de emergencia al terminar el tiempo.',
                    textAlign: TextAlign.center, style: AppText.caption),
              ]),
            ),
            GestureDetector(
              onTap: () => _finish(AlertChoice.cancel),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
