import 'package:flutter/material.dart';

/// Paleta própria do Painel Administrativo, coerente com a identidade COMPY.
///
/// O azul e o verde da marca são os de uma quadra poliesportiva: a navegação
/// e o login usam a superfície azul com linhas brancas; o resto é discreto.
///
/// Contraste WCAG AA conferido em `test/admin_theme_test.dart`: texto sobre
/// cor de fundo a 4,5:1 e borda de componente (`outline`) a 3:1.
abstract final class AdminColors {
  // Piso da quadra: navegação, login e ação principal.
  static const Color primary = Color(0xFF1F3A8A);
  static const Color primaryPressed = Color(0xFF172D6E);
  // Fundo azul-claro de destaques informativos, com texto em [primary].
  static const Color primaryContainer = Color(0xFFDCE4F7);
  // Linha verde da quadra: só decoração sobre o azul, nunca texto.
  static const Color courtLine = Color(0xFF34D399);

  // Verde de "ativo" e de seleção, legível sobre branco.
  static const Color secondary = Color(0xFF047857);
  static const Color secondaryContainer = Color(0xFFD1FAE5);
  static const Color onSecondaryContainer = Color(0xFF064E3B);

  static const Color surface = Color(0xFFFFFFFF);
  // Fundo das páginas; os painéis brancos se destacam sobre ele.
  static const Color background = Color(0xFFF3F5F9);
  static const Color surfaceContainer = Color(0xFFE9EDF4);
  static const Color onSurface = Color(0xFF101C3F);
  static const Color onSurfaceVariant = Color(0xFF4B5675);
  // Borda de campos e botões contornados.
  static const Color outline = Color(0xFF7C86A0);
  // Divisórias decorativas, que não precisam de 3:1.
  static const Color outlineVariant = Color(0xFFDCE1EB);

  static const Color error = Color(0xFFB91C1C);
  static const Color errorContainer = Color(0xFFFDE8E8);
  static const Color onErrorContainer = Color(0xFF7F1D1D);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF713F12);
}
