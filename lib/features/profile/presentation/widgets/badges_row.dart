import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/badge.dart';

class BadgesRow extends StatelessWidget {
  const BadgesRow({required this.badges, super.key});

  final List<SportBadge> badges;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final b in badges)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                children: <Widget>[
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: b.color.withOpacity(0.2),
                    child: Icon(b.icon, color: b.color, size: 30),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 70,
                    child: Text(
                      b.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          // Badge "+ Ver mais" placeholder
          Column(
            children: <Widget>[
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.surfaceMuted,
                child: const Icon(Icons.add, color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 6),
              const Text('Ver mais', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
