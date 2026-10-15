import 'package:flutter/material.dart';

/// Paleta própria do Painel Administrativo, coerente com a identidade COMPY.
///
/// Contraste WCAG AA conferido em `test/admin_theme_test.dart`: texto sobre
/// cor de fundo a 4,5:1 e borda de componente (`outline`) a 3:1.
abstract final class AdminColors {
  static const Color primary = Color(0xFF1F3A8A);
  static const Color secondary = Color(0xFF047857);
  // Indicador do item selecionado na NavigationRail (Material 3).
  static const Color secondaryContainer = Color(0xFFD1FAE5);
  static const Color onSecondaryContainer = Color(0xFF064E3B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFF7F7F8);
  static const Color onSurface = Color(0xFF0A0A0A);
  // Borda de campos e botões contornados.
  static const Color outline = Color(0xFF85858F);
  // Divisórias decorativas, que não precisam de 3:1.
  static const Color outlineVariant = Color(0xFFE2E2E5);
  static const Color error = Color(0xFFB91C1C);
}
