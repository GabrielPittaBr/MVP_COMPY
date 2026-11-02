import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Cinco estrelas. Com [onChanged], é a entrada da nota; sem ele, só mostra.
///
/// A estrela cheia é laranja com contorno [AppColors.warningText]; a vazia é
/// só o contorno em [AppColors.onSurfaceMuted]. Os dois contornos ficam
/// visíveis sobre o branco (contraste AA de elemento gráfico).
class StarRating extends StatelessWidget {
  const StarRating({
    required this.value,
    this.onChanged,
    this.size = 24,
    super.key,
  });

  /// Nota de 1 a 5; nulo ou zero = nenhuma estrela cheia.
  final int? value;
  final ValueChanged<int>? onChanged;

  /// Tamanho do desenho da estrela. Na entrada, o alvo de toque tem pelo
  /// menos 48px, mesmo com estrelas menores.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var stars = 1; stars <= 5; stars++)
          _Star(
            stars: stars,
            filled: (value ?? 0) >= stars,
            selected: value == stars,
            size: size,
            onTap: onChanged == null ? null : () => onChanged!(stars),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({
    required this.stars,
    required this.filled,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final int stars;
  final bool filled;
  final bool selected;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final drawing = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (filled)
            Icon(Icons.star_rounded, size: size, color: AppColors.warning),
          Icon(
            Icons.star_border_rounded,
            size: size,
            color: filled ? AppColors.warningText : AppColors.onSurfaceMuted,
          ),
        ],
      ),
    );
    if (onTap == null) return ExcludeSemantics(child: drawing);

    final target = size + 12 < 48 ? 48.0 : size + 12;
    return Semantics(
      button: true,
      selected: selected,
      label: AppStrings.ratingStarsSemantics(stars),
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey<String>('star-$stars'),
        onTap: onTap,
        radius: target / 2,
        child: SizedBox(
          width: target,
          height: target,
          child: Center(child: drawing),
        ),
      ),
    );
  }
}
