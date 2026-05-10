import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Estilos tipográficos centralizados (Inter — Google Fonts).
abstract final class AppTextStyles {
  static TextTheme buildTextTheme() {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: AppColors.onSurface),
      headlineLarge: base.headlineLarge?.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: AppColors.onSurfaceMuted,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.onSurface),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.onSurface),
      bodySmall: base.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
      labelLarge: base.labelLarge?.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
