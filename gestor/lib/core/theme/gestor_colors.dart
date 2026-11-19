import 'package:flutter/material.dart';

/// Paleta neutra do painel, a mesma do painel admin.
///
/// O tema do local muda só a moldura (menu, cabeçalho e login). Agenda,
/// formulários e cores de estado ficam com estas cores em todos os temas.
abstract final class GestorColors {
  static const Color primary = Color(0xFF1F3A8A);
  static const Color primaryPressed = Color(0xFF172D6E);
  static const Color primaryContainer = Color(0xFFDCE4F7);

  static const Color secondary = Color(0xFF047857);
  static const Color secondaryContainer = Color(0xFFD1FAE5);
  static const Color onSecondaryContainer = Color(0xFF064E3B);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF3F5F9);
  static const Color surfaceContainer = Color(0xFFE9EDF4);
  static const Color onSurface = Color(0xFF101C3F);
  static const Color onSurfaceVariant = Color(0xFF4B5675);
  static const Color outline = Color(0xFF7C86A0);
  static const Color outlineVariant = Color(0xFFDCE1EB);

  static const Color error = Color(0xFFB91C1C);
  static const Color errorContainer = Color(0xFFFDE8E8);
  static const Color onErrorContainer = Color(0xFF7F1D1D);
  static const Color warning = Color(0xFFB45309);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF713F12);

  /// Cor das iniciais do Arena Exemplo: a do beach tennis no app.
  static const Color monogram = Color(0xFF6F5232);
}
