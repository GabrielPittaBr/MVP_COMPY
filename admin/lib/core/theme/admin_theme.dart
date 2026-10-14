import 'package:flutter/material.dart';

import 'admin_colors.dart';

abstract final class AdminTheme {
  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: AdminColors.primary,
      onPrimary: Colors.white,
      secondary: AdminColors.secondary,
      onSecondary: Colors.white,
      surface: AdminColors.surface,
      onSurface: AdminColors.onSurface,
      error: AdminColors.error,
      outline: AdminColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AdminColors.surface,
      cardTheme: const CardThemeData(
        color: AdminColors.surfaceContainer,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
