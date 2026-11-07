import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/mixed_title.dart';

/// Alerta – Lugar seguro (Figma 83:2586).
class SafeScreen extends StatelessWidget {
  const SafeScreen({super.key, required this.helpers, required this.elapsed});
  final List<String> helpers;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final who = switch (helpers.length) {
      0 => 'tu contacto de emergencia',
      1 => helpers.first,
      _ => '${helpers.sublist(0, helpers.length - 1).join(', ')} y ${helpers.last}',
    };
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 124,
                height: 124,
                decoration: const BoxDecoration(
                  gradient: AppColors.limeGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.limeGlow,
                ),
                child: const Icon(Icons.favorite_rounded, color: AppColors.primaryDark, size: 58),
              ),
            ),
            const SizedBox(height: 28),
            MixedTitle(bold: 'Qué alivio,', regular: '${AppState.instance.nombre} 💜'),
            const SizedBox(height: 10),
            Text('Estás en un lugar seguro. Avisamos a $who que ya estás bien.', style: AppText.body, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AppCard(
              child: Row(children: [
                _Stat(value: '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}', label: 'min de alerta'),
                _Stat(value: '${helpers.length}', label: 'aliadas acudieron'),
                const _Stat(value: '24 h', label: 'y se borra tu ruta'),
              ]),
            ),
            const Spacer(),
            AppButton(label: 'Volver al inicio', onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: AppText.h2.copyWith(color: AppColors.primary)),
          Text(label, style: AppText.caption, textAlign: TextAlign.center),
        ]),
      );
}
