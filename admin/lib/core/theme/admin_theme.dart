import 'package:flutter/material.dart';

import 'admin_colors.dart';

abstract final class AdminTheme {
  /// Família condensada para títulos e números, como placas e placares.
  static const String displayFamily = 'BarlowCondensed';

  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AdminColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE4F7),
      onPrimaryContainer: AdminColors.primary,
      secondary: AdminColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AdminColors.secondaryContainer,
      onSecondaryContainer: AdminColors.onSecondaryContainer,
      surface: AdminColors.surface,
      onSurface: AdminColors.onSurface,
      onSurfaceVariant: AdminColors.onSurfaceVariant,
      surfaceContainerLowest: AdminColors.surface,
      surfaceContainerLow: AdminColors.background,
      surfaceContainer: AdminColors.background,
      surfaceContainerHigh: AdminColors.surfaceContainer,
      surfaceContainerHighest: AdminColors.surfaceContainer,
      surfaceTint: Colors.transparent,
      inverseSurface: AdminColors.onSurface,
      onInverseSurface: Colors.white,
      error: AdminColors.error,
      errorContainer: AdminColors.errorContainer,
      onErrorContainer: AdminColors.onErrorContainer,
      outline: AdminColors.outline,
      outlineVariant: AdminColors.outlineVariant,
    );

    // Escala tipográfica clássica (12/14/16/21/28/36/56).
    const ink = AdminColors.onSurface;
    const condensed = TextStyle(
      fontFamily: displayFamily,
      fontWeight: FontWeight.w600,
      color: ink,
    );
    // Família explícita: botões e snackbars usam o estilo como veio, sem
    // herdar a fonte do tema. Sem o espaçamento extra do Material 3, que
    // deixa a Barlow frouxa.
    const sans = TextStyle(fontFamily: 'Barlow', letterSpacing: 0);
    final textTheme = TextTheme(
      displaySmall: condensed.copyWith(
        fontSize: 56,
        height: 1,
        fontFeatures: tabularFigures,
      ),
      headlineMedium: condensed.copyWith(fontSize: 36, height: 1.1),
      headlineSmall: condensed.copyWith(fontSize: 28, height: 1.15),
      titleLarge: sans.copyWith(
        fontSize: 21,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: sans.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: sans.copyWith(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: sans.copyWith(fontSize: 16, height: 1.5, color: ink),
      bodyMedium: sans.copyWith(fontSize: 14, height: 1.45, color: ink),
      bodySmall: sans.copyWith(
        fontSize: 12,
        height: 1.4,
        color: AdminColors.onSurfaceVariant,
      ),
      labelLarge: sans.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: sans.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: sans.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    );

    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );
    const controlSize = Size(0, 44);
    const controlPadding = EdgeInsets.symmetric(horizontal: 18);
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Barlow',
      textTheme: textTheme,
      scaffoldBackgroundColor: AdminColors.background,
      canvasColor: AdminColors.surface,
      dividerTheme: const DividerThemeData(
        color: AdminColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: AdminColors.outlineVariant)),
        titleTextStyle: TextStyle(
          fontFamily: displayFamily,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AdminColors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: AdminColors.onSurfaceVariant),
        floatingLabelStyle: const TextStyle(color: AdminColors.primary),
        prefixIconColor: AdminColors.onSurfaceVariant,
        border: inputBorder(AdminColors.outline),
        enabledBorder: inputBorder(AdminColors.outline),
        disabledBorder: inputBorder(AdminColors.outlineVariant),
        focusedBorder: inputBorder(AdminColors.primary, 2),
        errorBorder: inputBorder(AdminColors.error),
        focusedErrorBorder: inputBorder(AdminColors.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          foregroundColor: AdminColors.primary,
          backgroundColor: AdminColors.surface,
          side: const BorderSide(color: AdminColors.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: controlSize,
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.surface,
        selectedColor: AdminColors.secondaryContainer,
        checkmarkColor: AdminColors.onSecondaryContainer,
        side: const BorderSide(color: AdminColors.outline),
        shape: const StadiumBorder(),
        labelStyle: sans.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        titleTextStyle: textTheme.headlineSmall,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: sans.copyWith(fontSize: 14, color: Colors.white),
        shape: controlShape,
      ),
      popupMenuTheme: const PopupMenuThemeData(color: AdminColors.surface),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AdminColors.primary,
        shape: RoundedRectangleBorder(),
        width: 288,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: sans.copyWith(fontSize: 12, color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.primary,
        linearTrackColor: AdminColors.surfaceContainer,
      ),
    );
  }
}
