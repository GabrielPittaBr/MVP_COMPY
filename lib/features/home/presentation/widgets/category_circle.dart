import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/sport_category.dart';

/// Diâmetro compartilhado pelos itens do carrossel — as categorias e o
/// "Ver mais" precisam do mesmo tamanho para a fileira não ficar torta.
const double _circleSize = 72;

/// Item circular usado no carrossel "Categorias" da home.
class CategoryCircle extends StatelessWidget {
  const CategoryCircle({
    required this.category,
    required this.onTap,
    super.key,
  });

  final SportCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: <Widget>[
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: category.imageUrl,
              width: _circleSize,
              height: _circleSize,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 72,
                height: 72,
                color: AppColors.surfaceMuted,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: category.sport.color.withValues(alpha: 0.15),
                child: Icon(category.sport.icon, color: category.sport.color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.sport.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Último item do carrossel: abre o seletor com todas as modalidades.
///
/// A Home mostra só um punhado de categorias; sem esta porta de entrada os
/// outros esportes do enum ficariam inalcançáveis.
class MoreCategoriesCircle extends StatelessWidget {
  const MoreCategoriesCircle({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: <Widget>[
          Container(
            width: _circleSize,
            height: _circleSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceMuted,
            ),
            child: const Icon(
              Icons.grid_view,
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            AppStrings.homeSeeMoreCategories,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
