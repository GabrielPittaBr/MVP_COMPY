import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/rating_summary.dart';

/// Bloco com a média de estrelas + barras de distribuição (1 a 5).
class RatingBreakdown extends StatelessWidget {
  const RatingBreakdown({required this.summary, super.key});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              summary.average.toStringAsFixed(1),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
            ),
            Row(
              children: List<Widget>.generate(
                5,
                (i) => Icon(
                  i < summary.average.round() ? Icons.star : Icons.star_border,
                  color: AppColors.warning,
                  size: 16,
                ),
              ),
            ),
            Text(
              '${summary.count} avaliações',
              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
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
