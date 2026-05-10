import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Galeria horizontal de fotos do perfil (RF10).
class PhotoGallery extends StatelessWidget {
  const PhotoGallery({required this.photos, super.key});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: photos[i],
            width: 200,
            height: 120,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 200,
              color: AppColors.surfaceMuted,
            ),
          ),
        ),
      ),
    );
  }
}
