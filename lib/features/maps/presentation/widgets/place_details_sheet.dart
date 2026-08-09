import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport_place.dart';

/// Bottom sheet exibido ao tocar em um pin (RF04 — informações do local +
/// ação de criar evento ali).
///
/// D11: "Favoritar" saiu — não existe modelo de local favorito e botão
/// inerte é pior que botão ausente. "Compartilhar" volta na tarefa 9,
/// junto com o chat, que é para onde um local compartilhado vai.
class PlaceDetailsSheet extends StatelessWidget {
  const PlaceDetailsSheet({
    required this.place,
    required this.onCreateEvent,
    super.key,
  });

  final SportPlace place;
  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // Sem `expand: false` o sheet ocupa o Stack inteiro e o Scrollable
      // interno engole os toques na área transparente acima do card —
      // era isso que impedia de tocar no mapa para fechá-lo.
      expand: false,
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
                    child: Icon(
                    place.primarySport.icon,
                    size: 60,
                    color: place.primarySport.color,
                  ),
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
                      // Endereço completo só quando conferido; senão a
                      // cidade já situa o local.
                      place.address.isEmpty ? place.city : place.address,
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Esportes praticáveis — os mesmos que o seletor de
                    // "Criar evento" oferece para este local.
                    _SportsWrap(place: place),
                    // Local sem nenhuma avaliação não mostra nota nenhuma
                    // (nada de 0,0 estrelas em local real).
                    if (place.hasRatings) ...<Widget>[
                      const SizedBox(height: 12),
                      _RatingRow(
                        rating: place.rating,
                        count: place.ratingsCount,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Center(
                      child: _ActionButton(
                        icon: Icons.add,
                        label: AppStrings.eventCreate,
                        onTap: onCreateEvent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      AppStrings.mapsPlaceInfo,
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

class _SportsWrap extends StatelessWidget {
  const _SportsWrap({required this.place});
  final SportPlace place;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final sport in place.allowedSports)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(sport.icon, size: 14, color: sport.color),
                const SizedBox(width: 6),
                Text(sport.label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
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
