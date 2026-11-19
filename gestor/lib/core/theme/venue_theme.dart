import 'package:flutter/material.dart';

import 'court_painter.dart';

/// Tema do Local: muda só a moldura (menu, cabeçalho, login e divulgação).
///
/// Cores da tabela de temas de `docs/gestores/requisitos-painel-do-local.md`,
/// com o contraste AA conferido em `test/gestor_test.dart`.
enum VenueTheme {
  quadra(
    'Quadra',
    'Futsal, handebol, tênis de mesa e locais sem quadra',
    CourtStyle.quadra,
    accent: Color(0xFF34D399),
    selected: Color(0xFF182D6C),
  ),
  areia(
    'Areia',
    'Beach tennis, vôlei de praia, futevôlei e futebol de areia',
    CourtStyle.areia,
    accent: Color(0xFF1D4ED8),
    selected: Color(0xFFF1E5CA),
  ),
  padel(
    'Padel',
    'Padel',
    CourtStyle.padel,
    accent: Color(0xFFA3E635),
    selected: Color(0xFF173D6D),
  ),
  campo(
    'Campo',
    'Futebol society',
    CourtStyle.campo,
    accent: Color(0xFFFACC15),
    selected: Color(0xFF17532D),
  ),
  saibro(
    'Saibro',
    'Tênis',
    CourtStyle.saibro,
    accent: Color(0xFFFDE68A),
    selected: Color(0xFF833A1C),
  ),
  ginasio(
    'Ginásio',
    'Vôlei e basquete',
    CourtStyle.ginasio,
    accent: Color(0xFFFBBF24),
    selected: Color(0xFF6C401F),
  );

  const VenueTheme(
    this.label,
    this.sports,
    this.court, {
    required this.accent,
    required this.selected,
  });

  final String label;
  final String sports;
  final CourtStyle court;

  /// Destaque do item selecionado no menu.
  final Color accent;

  /// Fundo do item selecionado no menu.
  final Color selected;

  Color get floor => court.floor;
  Color get ink => court.ink;
  Color get ink2 => court.ink.withValues(alpha: 0.9);
}
