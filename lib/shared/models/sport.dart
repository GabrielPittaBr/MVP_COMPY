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
}
