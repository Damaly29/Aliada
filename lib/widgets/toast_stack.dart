import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ToastMessage {
  ToastMessage(this.text, {this.icon = Icons.favorite_rounded}) : id = DateTime.now().microsecondsSinceEpoch;
  final int id;
  final String text;
  final IconData icon;
}

/// Pila de toasts dinámicos (máx. 2) con entrada/salida animada.
class ToastStack extends StatelessWidget {
  const ToastStack({super.key, required this.toasts});
  final List<ToastMessage> toasts;

  @override
  Widget build(BuildContext context) {
    final visible = toasts.length > 2 ? toasts.sublist(toasts.length - 2) : toasts;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          for (final t in visible)
            TweenAnimationBuilder<double>(
              key: ValueKey(t.id),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Opacity(
                opacity: v.clamp(0, 1),
                child: Transform.translate(offset: Offset(0, -16 * (1 - v)), child: child),
              ),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(children: [
                    Icon(t.icon, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.text, style: AppText.bodyStrong)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
