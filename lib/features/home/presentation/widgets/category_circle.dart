import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/sport_category.dart';

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
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 72,
                height: 72,
                color: AppColors.surfaceMuted,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: category.sport.color.withOpacity(0.15),
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
