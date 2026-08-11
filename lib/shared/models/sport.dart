import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';

/// Modalidades esportivas suportadas no MVP.
///
/// Centralizar como enum garante que filtros, ícones e categorias
/// referenciem os mesmos valores em todo o app.
enum Sport {
  futebol(
    label: 'Futebol',
    icon: Icons.sports_soccer,
    color: AppColors.success,
    banner: AppAssets.soccerBanner,
  ),
  basquete(
    label: 'Basquete',
    icon: Icons.sports_basketball,
    color: Color(0xFFE76F51),
    banner: AppAssets.basketballBanner,
  ),
  volei(
    label: 'Vôlei',
    icon: Icons.sports_volleyball,
    color: Color(0xFFF4A261),
    banner: AppAssets.volleyballBanner,
  ),
  tenisDeMesa(
    label: 'Tênis de mesa',
    icon: Icons.sports_tennis,
    color: Color(0xFFE63946),
    banner: AppAssets.tableTennisBanner,
  ),
  futsal(
    label: 'Futsal',
    icon: Icons.sports_soccer,
    color: Color(0xFF2A9D8F),
    banner: AppAssets.soccerBanner,
  ),
  corrida(
    label: 'Corrida',
    icon: Icons.directions_run,
    color: Color(0xFF457B9D),
    banner: AppAssets.runningBanner,
  ),
  ciclismo(
    label: 'Ciclismo',
    icon: Icons.directions_bike,
    color: Color(0xFF6D597A),
    banner: AppAssets.cyclingBanner,
  ),
  caminhada(
    label: 'Caminhada',
    icon: Icons.directions_walk,
    color: Color(0xFF588157),
    banner: AppAssets.walkingBanner,
  );

  const Sport({
    required this.label,
    required this.icon,
    required this.color,
    required this.banner,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String banner;

  // ───────────────────────────────────────────────────────────────────────
  // Persistência
  // ───────────────────────────────────────────────────────────────────────

  /// Nome sob o qual o esporte é gravado no Firestore.
  ///
  /// É o próprio `name` do enum. Renomear um valor invalida os documentos já
  /// gravados — o acoplamento fica explícito aqui em vez de espalhado pelos
  /// mapeadores.
  String get storageName => name;

  /// Chave do array de esportes favoritos em `users/{uid}`.
  static const String favoriteSportsField = 'favoriteSports';

  /// Nome gravado → esporte, ou `null` se esse nome não existe mais.
  ///
  /// Tolerante de propósito: um valor removido do enum, ou um documento
  /// escrito à mão, não pode derrubar a leitura do perfil inteiro.
  static Sport? tryParse(Object? raw) {
    if (raw is! String) return null;
    for (final Sport sport in values) {
      if (sport.storageName == raw) return sport;
    }
    return null;
  }

  /// Array gravado → esportes, descartando nomes desconhecidos e duplicatas.
  /// Campo ausente ou de tipo errado vira lista vazia.
  static List<Sport> parseList(Object? raw) {
    if (raw is! List) return const <Sport>[];
    final List<Sport> parsed = <Sport>[];
    for (final Object? item in raw) {
      final Sport? sport = tryParse(item);
      if (sport != null && !parsed.contains(sport)) parsed.add(sport);
    }
    return parsed;
  }

  /// Esportes → array gravável.
  static List<String> toStorage(Iterable<Sport> sports) =>
      sports.map((Sport s) => s.storageName).toList();

  /// `true` quando o documento já registrou uma escolha de esportes —
  /// inclusive a escolha vazia de quem pulou o onboarding.
  ///
  /// É a **presença do campo** que conta, não o tamanho da lista. Exigir ao
  /// menos um esporte aqui faria o guard do router devolver quem pulou de
  /// volta para o onboarding, indefinidamente.
  static bool hasStoredFavorites(Map<String, dynamic>? data) =>
      data != null && data.containsKey(favoriteSportsField);
}
