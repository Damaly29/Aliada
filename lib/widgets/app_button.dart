import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, lime, ghost }

class AppButton extends StatefulWidget {
  const AppButton({super.key, required this.label, this.onPressed, this.variant = AppButtonVariant.primary, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final (gradient, fg, shadow) = switch (widget.variant) {
      AppButtonVariant.primary => (AppColors.primaryGradient, AppColors.white, AppShadows.floating),
      AppButtonVariant.lime => (AppColors.limeGradient, AppColors.limeText, AppShadows.limeGlow),
      AppButtonVariant.ghost => (null, AppColors.primary, const <BoxShadow>[]),
    };
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(AppRadius.md);
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient,
              color: widget.variant == AppButtonVariant.ghost ? AppColors.primaryMist : null,
              borderRadius: radius,
              boxShadow: enabled ? shadow : null,
            ),
            child: TextButton(
              onPressed: widget.onPressed,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: fg,
                disabledForegroundColor: fg.withValues(alpha: 0.5),
                overlayColor: fg.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: radius),
                textStyle: AppText.button,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: 8)],
                  Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
