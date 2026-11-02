import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../models/skill_level.dart';

/// Mesmo rótulo de nível nos cards, detalhes e evento em andamento.
class EventSkillLevelChip extends StatelessWidget {
  const EventSkillLevelChip({
    required this.level,
    this.compact = false,
    super.key,
  });

  final SkillLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = level == SkillLevel.todos
        ? AppStrings.eventAllSkillLevels
        : level.label;
    return Semantics(
      label: '${AppStrings.eventSkillLevel}: $label',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.trending_up_outlined,
                  size: 16,
                  color: AppColors.onSurfaceMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    compact ? label : '${AppStrings.eventSkillLevel}: $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
