import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40, this.color = AppColors.primary, this.ring = AppColors.white});
  final String name;
  final double size;
  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(w[0]));
    final initials = words.take(2).map((w) => w[0]).join().toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2.5),
        boxShadow: AppShadows.card,
      ),
      child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, color: AppColors.white, fontSize: size * 0.36)),
    );
  }
}
