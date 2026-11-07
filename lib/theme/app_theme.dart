import 'package:flutter/material.dart';

/// Tokens del diseño (Figma "Design-Thinking").
abstract final class AppColors {
  static const primary = Color(0xFF765AD0);
  static const primaryDark = Color(0xFF5B42B0);
  static const primarySoft = Color(0xFFEDE8FA);
  // Lima del botón "Llamar a…" y la X de cancelar (captura del Figma 69:1287).
  static const lime = Color(0xFFBDE38C);
  static const limeText = Color(0xFF2B2B2B);
  static const gray = Color(0xFF8D8D8D);
  static const grayLight = Color(0xFFE4E4E4);
  static const text = Color(0xFF2B2B2B);
  static const white = Colors.white;
  static const background = Colors.white;
  static const backgroundSoft = Color(0xFFF4F1FC);
  static const lavenderChip = Color(0xFFEEEAFA);
  static const border = Color(0xFFDCDCE4);
  // Modal "¿Qué peligro hay?"
  static const alertRed = Color(0xFFE0342B);
  static const alertYellow = Color(0xFFEEDC6B);
  static const alertBlack = Color(0xFF1C1F1F);
  static const danger = Color(0xFFE5484D);
  static const userDot = Color(0xFF2F80ED);
}

abstract final class AppFonts {
  static const title = 'Montserrat';
  static const ui = 'OpenSans';
}

abstract final class AppShadows {
  /// Figma: 1px 1px 5px rgba(0,0,0,0.15)
  static const card = [BoxShadow(offset: Offset(1, 1), blurRadius: 5, color: Color(0x26000000))];
  static const floating = [BoxShadow(offset: Offset(0, 4), blurRadius: 14, color: Color(0x59765AD0))];
}

abstract final class AppText {
  static const h1 = TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.text, height: 1.25);
  static const h2 = TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.text, height: 1.3);
  static const h3 = TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.text, height: 1.3);
  static const body = TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: AppColors.text, height: 1.4);
  static const bodyStrong = TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text, height: 1.4);
  static const caption = TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: AppColors.gray, height: 1.35);
  static const button = TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 15);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      ),
    );
