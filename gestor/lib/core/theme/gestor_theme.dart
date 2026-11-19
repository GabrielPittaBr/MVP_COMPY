import 'package:flutter/material.dart';

import 'gestor_colors.dart';

/// Tema Material do painel, com a base do painel admin.
abstract final class GestorTheme {
  /// Família condensada para títulos e números, como placas e placares.
  static const String display = 'BarlowCondensed';

  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: GestorColors.primary,
      onPrimary: Colors.white,
      primaryContainer: GestorColors.primaryContainer,
      onPrimaryContainer: GestorColors.primary,
      secondary: GestorColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: GestorColors.secondaryContainer,
      onSecondaryContainer: GestorColors.onSecondaryContainer,
      surface: GestorColors.surface,
      onSurface: GestorColors.onSurface,
      onSurfaceVariant: GestorColors.onSurfaceVariant,
      surfaceContainerLowest: GestorColors.surface,
      surfaceContainerLow: GestorColors.background,
      surfaceContainer: GestorColors.background,
      surfaceContainerHigh: GestorColors.surfaceContainer,
      surfaceContainerHighest: GestorColors.surfaceContainer,
      surfaceTint: Colors.transparent,
      inverseSurface: GestorColors.onSurface,
      onInverseSurface: Colors.white,
      error: GestorColors.error,
      errorContainer: GestorColors.errorContainer,
      onErrorContainer: GestorColors.onErrorContainer,
      outline: GestorColors.outline,
      outlineVariant: GestorColors.outlineVariant,
    );

    const ink = GestorColors.onSurface;
    const condensed = TextStyle(
      fontFamily: display,
      fontWeight: FontWeight.w600,
      color: ink,
    );
    const sans = TextStyle(fontFamily: 'Barlow', letterSpacing: 0);
    final text = TextTheme(
      displaySmall: condensed.copyWith(
        fontSize: 56,
        height: 1,
        fontFeatures: tabular,
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
        color: GestorColors.onSurfaceVariant,
      ),
      labelLarge: sans.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: sans.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: sans.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    );

    const control = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );
    const controlSize = Size(0, 48);
    const controlPadding = EdgeInsets.symmetric(horizontal: 18);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Barlow',
      textTheme: text,
      scaffoldBackgroundColor: GestorColors.background,
      canvasColor: GestorColors.surface,
      visualDensity: VisualDensity.standard,
      dividerTheme: const DividerThemeData(
        color: GestorColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GestorColors.surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: GestorColors.outlineVariant)),
        titleTextStyle: TextStyle(
          fontFamily: display,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      cardTheme: const CardThemeData(
        color: GestorColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: GestorColors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GestorColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: GestorColors.onSurfaceVariant),
        floatingLabelStyle: const TextStyle(color: GestorColors.primary),
        border: border(GestorColors.outline),
        enabledBorder: border(GestorColors.outline),
        disabledBorder: border(GestorColors.outlineVariant),
        focusedBorder: border(GestorColors.primary, 2),
        errorBorder: border(GestorColors.error),
        focusedErrorBorder: border(GestorColors.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: control,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: control,
          foregroundColor: ink,
          backgroundColor: GestorColors.surface,
          side: const BorderSide(color: GestorColors.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: control,
          textStyle: text.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: text.labelLarge,
          selectedBackgroundColor: GestorColors.primaryContainer,
          selectedForegroundColor: GestorColors.primary,
          side: const BorderSide(color: GestorColors.outline),
          shape: control,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: GestorColors.surface,
        selectedColor: GestorColors.primaryContainer,
        checkmarkColor: GestorColors.primary,
        side: const BorderSide(color: GestorColors.outline),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        labelStyle: sans.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(GestorColors.outline),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GestorColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        titleTextStyle: text.headlineSmall,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GestorColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: sans.copyWith(fontSize: 15, color: Colors.white),
        actionTextColor: const Color(0xFFA5B4FC),
        shape: control,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: sans.copyWith(fontSize: 12, color: Colors.white),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}
