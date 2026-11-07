import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, lime, ghost }

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, this.onPressed, this.variant = AppButtonVariant.primary, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, AppColors.white, AppColors.primary),
      AppButtonVariant.lime => (AppColors.lime, AppColors.limeText, AppColors.lime),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.primary, AppColors.primary),
    };
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: border, width: 1.5)),
          textStyle: AppText.button,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
