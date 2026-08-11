import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/sport.dart';

/// Ladrilho de modalidade em grade, com estado de seleção.
///
/// Compartilhado entre o filtro de eventos (seleção única) e a escolha de
/// esportes favoritos (múltipla): quem decide o que "selecionado" significa é
/// quem monta a grade — aqui só muda a aparência.
class SportSelectTile extends StatelessWidget {
  const SportSelectTile({
    required this.sport,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final Sport sport;
  final bool isSelected;

  /// `null` desabilita o ladrilho — sem toque e sem ripple.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? sport.color.withValues(alpha: 0.18)
                  : AppColors.surfaceMuted,
              border: Border.all(
                color: isSelected ? sport.color : AppColors.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              sport.icon,
              color: isSelected ? sport.color : AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 6),
          // Flexible: "Tênis de mesa" ocupa duas linhas, e com fonte
          // ampliada pelo sistema ocuparia mais altura do que a célula tem.
          // Sem isto o rótulo estoura a grade em vez de encolher.
          Flexible(
            child: Text(
              sport.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color:
                    isSelected ? AppColors.onSurface : AppColors.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
