import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rating_format.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../ratings/domain/entities/rating_summary.dart';
import '../../../ratings/presentation/providers/ratings_providers.dart';

/// Nota do Local Esportivo na ficha do mapa: "★★★★☆ 4,3 (23 avaliações)",
/// ou "Sem avaliações ainda" em cinza (tarefa 14).
///
/// Lê `ratingSummaries/place_{id}`, e não o documento do local: `places`
/// tem contrato estrito de 11 campos, sem nota.
class PlaceRatingRow extends ConsumerWidget {
  const PlaceRatingRow({required this.placeId, super.key});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(
            ratingSummaryProvider((type: RatingTargetType.place, id: placeId)))
        .valueOrNull;
    if (summary == null) return const SizedBox(height: 24);
    if (!summary.hasRatings) {
      return const Text(
        AppStrings.ratingsNone,
        style: TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
      );
    }
    return Row(
      children: <Widget>[
        StarRating(value: summary.average.round(), size: 18),
        const SizedBox(width: 8),
        Text(
          RatingFormat.average(summary.average),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Text(
          '(${AppStrings.ratingsCount(summary.count)})',
          style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}
