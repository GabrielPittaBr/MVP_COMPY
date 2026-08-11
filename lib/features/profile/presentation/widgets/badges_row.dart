import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/badge.dart';

class BadgesRow extends StatelessWidget {
  const BadgesRow({
    required this.badges,
    required this.onSeeMore,
    super.key,
  });

  final List<SportBadge> badges;

  /// Abre a tela das insígnias. Hoje [badges] chega vazia do Firestore, então
  /// este é o único item clicável da fileira — e o único jeito de a seção não
  /// parecer quebrada.
  final VoidCallback onSeeMore;

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
          Semantics(
            button: true,
            child: InkWell(
              onTap: onSeeMore,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Column(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.surfaceMuted,
                      child: Icon(Icons.add, color: AppColors.onSurfaceMuted),
                    ),
                    SizedBox(height: 6),
                    Text(
                      AppStrings.profileSeeMore,
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
