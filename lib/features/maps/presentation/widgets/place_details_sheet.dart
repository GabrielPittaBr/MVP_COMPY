import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/sport_place.dart';

/// Bottom sheet exibido ao tocar em um pin (RF04 — informações do local +
/// ações: criar evento / compartilhar / favoritar).
class PlaceDetailsSheet extends StatelessWidget {
  const PlaceDetailsSheet({
    required this.place,
    required this.onCreateEvent,
    required this.onShare,
    required this.onFavorite,
    super.key,
  });

  final SportPlace place;
  final VoidCallback onCreateEvent;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: <Widget>[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: CachedNetworkImage(
                  imageUrl: place.imageUrl,
                  height: 200,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: AppColors.surfaceMuted,
                    child: Icon(place.sport.icon, size: 60, color: place.sport.color),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place.address,
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RatingRow(rating: place.rating, count: place.ratingsCount),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _ActionButton(
                          icon: Icons.add,
                          label: 'Criar evento',
                          onTap: onCreateEvent,
                        ),
                        _ActionButton(
                          icon: Icons.share_outlined,
                          label: 'Compartilhar',
                          onTap: onShare,
                        ),
                        _ActionButton(
                          icon: Icons.bookmark_outline,
                          label: 'Favoritar',
                          onTap: onFavorite,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Informações',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      place.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        ...List<Widget>.generate(5, (i) {
          final filled = i < rating.round();
          return Icon(
            filled ? Icons.star : Icons.star_border,
            size: 18,
            color: filled ? AppColors.warning : AppColors.outline,
          );
        }),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
