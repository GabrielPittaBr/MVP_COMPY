import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../models/skill_level.dart';

/// Linha informativa dos detalhes: ícone e texto que pode quebrar linha.
class EventInfoRow extends StatelessWidget {
  const EventInfoRow({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.onSurface,
    this.semanticLabel,
    super.key,
  });

  factory EventInfoRow.skillLevel({required SkillLevel level, Key? key}) {
    final label = level == SkillLevel.todos
        ? AppStrings.eventAllSkillLevels
        : level.label;
    return EventInfoRow(
      key: key,
      icon: Icons.trending_up_outlined,
      label: label,
      semanticLabel: '${AppStrings.eventSkillLevel}: $label',
    );
  }

  final IconData icon;
  final String label;
  final Color iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
}
