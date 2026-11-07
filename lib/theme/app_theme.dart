import 'package:flutter/material.dart';

/// Tokens del diseño (Figma "Design-Thinking").
///
/// Paleta: lavanda cálida + un único acento morado y el lima de acción.
/// Todo gris está tintado hacia el morado para que las superficies no se sientan frías.
abstract final class AppColors {
  static const primary = Color(0xFF6E4FD8);
  static const primaryDark = Color(0xFF4A2FA8);
  static const primaryDeep = Color(0xFF3A2185);
  static const primarySoft = Color(0xFFEDE7FC);
  static const primaryMist = Color(0xFFF4F0FE);
  // Lima del botón "Llamar a…" y la X de cancelar.
  static const lime = Color(0xFFC7E88F);
  static const limeDeep = Color(0xFFA6D45E);
  static const limeText = Color(0xFF26331A);
  static const gray = Color(0xFF7A7488);
  static const grayLight = Color(0xFFE9E5F2);
  static const text = Color(0xFF231A38);
  static const textSoft = Color(0xFF5C5470);
  static const white = Colors.white;
  static const surface = Colors.white;
  static const background = Color(0xFFF6F3FC);
  static const backgroundSoft = Color(0xFFF8F6FD);
  static const lavenderChip = Color(0xFFEFEAFB);
  static const border = Color(0xFFE7E2F1);
  // Modal "¿Qué peligro hay?"
  static const alertRed = Color(0xFFE23A2E);
  static const alertYellow = Color(0xFFF0DE72);
  static const alertBlack = Color(0xFF1C1F1F);
  static const danger = Color(0xFFE5484D);
  static const userDot = Color(0xFF2F80ED);

  static const gradientStart = Color(0xFF8262EC);
  static const gradientEnd = Color(0xFF5232BB);

  /// Superficie principal de marca (headers, hero cards).
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  /// Lavado suave para fondos de tarjetas destacadas.
  static const mistGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6F2FF), Color(0xFFFDFBFF)],
  );

  static const limeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD3EE9F), Color(0xFFB2DB6C)],
  );
}

abstract final class AppFonts {
  static const title = 'Montserrat';
  static const ui = 'OpenSans';
}

/// Escala de radios: pequeño para controles, grande para superficies.
abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  /// Sombra de contacto: muy sutil, para elementos pequeños.
  static const soft = [
    BoxShadow(color: Color(0x0F2E1A66), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// Tarjetas: dos capas (ambiente + contacto) tintadas de morado, nunca negro puro.
  static const card = [
    BoxShadow(color: Color(0x12281866), blurRadius: 26, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0A281866), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Botón central y elementos flotantes.
  static const floating = [
    BoxShadow(color: Color(0x4D5B3FC8), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x1F281866), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const limeGlow = [
    BoxShadow(color: Color(0x4DA6D45E), blurRadius: 22, offset: Offset(0, 8)),
  ];
}

abstract final class AppText {
  static const h1 = TextStyle(
    fontFamily: AppFonts.title,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    letterSpacing: -0.7,
    color: AppColors.text,
    height: 1.18,
  );
  static const h2 = TextStyle(
    fontFamily: AppFonts.title,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    letterSpacing: -0.3,
    color: AppColors.text,
    height: 1.25,
  );
  static const h3 = TextStyle(
    fontFamily: AppFonts.title,
    fontWeight: FontWeight.w700,
    fontSize: 16.5,
    letterSpacing: -0.2,
    color: AppColors.text,
    height: 1.3,
  );
  static const body = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 14.5,
    color: AppColors.text,
    height: 1.5,
  );
  static const bodyStrong = TextStyle(
    fontFamily: AppFonts.ui,
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    color: AppColors.text,
    height: 1.5,
  );
  static const caption = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 12.5,
    color: AppColors.gray,
    height: 1.45,
  );

  /// Etiquetas de sección ("AGENDA", "MENSAJES").
  static const label = TextStyle(
    fontFamily: AppFonts.ui,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 1.1,
    color: AppColors.gray,
    height: 1.2,
  );
  static const button = TextStyle(
    fontFamily: AppFonts.ui,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    letterSpacing: 0.1,
  );
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.text),
        titleTextStyle: AppText.h3,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: AppText.h2,
        contentTextStyle: AppText.body.copyWith(color: AppColors.textSoft),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: AppText.body.copyWith(color: AppColors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.primaryMist,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: AppText.body.copyWith(color: AppColors.gray, fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppText.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),
    );
