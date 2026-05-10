import 'package:flutter/material.dart';

/// Paleta de cores estratégica do COMPY (RNF04: branco, preto, azul e verde).
///
/// Os valores foram calibrados para garantir contraste WCAG AA (RNF09)
/// quando aplicados nas combinações texto/superfície previstas no design.
abstract final class AppColors {
  // Cores principais
  static const Color primary = Color(0xFF1F3A8A); // Azul profundo
  static const Color primaryDark = Color(0xFF0B2566);
  static const Color secondary = Color(0xFF10B981); // Verde esportivo

  // Superfícies
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F1F4); // Fundo de campos arredondados
  static const Color surfaceCard = Color(0xFFF7F7F8);

  // Tipografia
  static const Color onSurface = Color(0xFF0A0A0A);
  static const Color onSurfaceMuted = Color(0xFF6B7280);

  // Bordas / divisores
  static const Color outline = Color(0xFFE2E2E5);
  static const Color outlineSoft = Color(0xFFEFEFF1);

  // Estado
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);

  // Bottom nav (item ativo herda preto, conforme mockup)
  static const Color navActive = Color(0xFF0A0A0A);
  static const Color navInactive = Color(0xFF6B7280);
}
