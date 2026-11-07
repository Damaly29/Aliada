import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "**Hola,** Nicolle": Montserrat Bold + Regular.
class MixedTitle extends StatelessWidget {
  const MixedTitle({super.key, required this.bold, this.regular, this.size = 24, this.color = AppColors.text});
  final String bold;
  final String? regular;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text.rich(TextSpan(
        style: TextStyle(fontFamily: AppFonts.title, fontSize: size, color: color, height: 1.25),
        children: [
          TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (regular != null) TextSpan(text: ' $regular', style: const TextStyle(fontWeight: FontWeight.w400)),
        ],
      )),
    );
  }
}
