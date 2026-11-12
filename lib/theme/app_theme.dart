import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF14573F);
  static const forestDark = Color(0xFF0C3A2A);
  static const mint = Color(0xFFD9F2E4);
  static const mintSoft = Color(0xFFF3F9F5);
  static const mango = Color(0xFFF2994A);
  static const mangoSoft = Color(0xFFFFE9D2);
  static const berry = Color(0xFFD64F6B);
  static const ink = Color(0xFF16231D);
  static const inkSoft = Color(0xFF5E6F66);
  static const surfaceVariant = Color(0xFFE6EFE9);
}

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.forest,
    onPrimary: Colors.white,
    primaryContainer: AppColors.mint,
    onPrimaryContainer: AppColors.forestDark,
    secondary: AppColors.mango,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.mangoSoft,
    onSecondaryContainer: Color(0xFF5A3000),
    surface: Colors.white,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.surfaceVariant,
    onSurfaceVariant: AppColors.inkSoft,
    error: AppColors.berry,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.mintSoft,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
  );
}
