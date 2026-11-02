import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rating_format.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../ratings/domain/entities/rating_summary.dart';

/// Bloco com a média de estrelas + barras de distribuição (1 a 5).
///
/// A média vem de `ratingSummaries` (tarefa 14) e aparece com vírgula
/// decimal ("4,8"). Nenhum comentário aparece aqui (D13).
class RatingBreakdown extends StatelessWidget {
  const RatingBreakdown({
    required this.summary,
    this.isOwnProfile = true,
    super.key,
  });

  final RatingSummary summary;

  /// O estado vazio fala em primeira pessoa ("Você ainda não…") só no
  /// próprio perfil; no de outra pessoa, é o neutro "Sem avaliações ainda".
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasRatings) {
      return isOwnProfile
          ? const _NoRatingsYet()
          : const Text(
              AppStrings.ratingsNone,
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
            );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              RatingFormat.average(summary.average),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
            ),
            StarRating(value: summary.average.round(), size: 16),
            Text(
              AppStrings.ratingsCount(summary.count),
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: <Widget>[
              for (int stars = 5; stars >= 1; stars--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      Text('$stars', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: summary.breakdown[stars] ?? 0,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceMuted,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${((summary.breakdown[stars] ?? 0) * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// O que ocupa o lugar da média enquanto ninguém avaliou.
///
/// Mostrar "0,0" com cinco estrelas vazias comunica nota mínima, não ausência
/// de nota.
class _NoRatingsYet extends StatelessWidget {
  const _NoRatingsYet();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.profileNoRatings,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        SizedBox(height: 4),
        Text(
          AppStrings.profileNoRatingsHint,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
