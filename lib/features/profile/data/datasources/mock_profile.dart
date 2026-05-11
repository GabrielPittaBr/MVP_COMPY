import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/rating_summary.dart';
import '../../domain/entities/user_profile.dart';

abstract final class MockProfile {
  static UserProfile get current => UserProfile(
        summary: UserSummary(
          id: 'u_joao',
          name: 'João Souza',
          handle: '@joao.souza',
          avatarUrl: AppAssets.avatar('João', size: 200),
        ),
        bio: 'Apaixonado por esportes coletivos. Busca parceiros para treinar em Taquara.',
        favoriteSports: const <Sport>[Sport.futebol, Sport.volei, Sport.basquete],
        badges: const <SportBadge>[
          SportBadge(
            id: 'b1',
            label: 'Craque da bola',
            icon: Icons.emoji_events,
            color: Color(0xFFE63946),
          ),
          SportBadge(
            id: 'b2',
            label: 'Vôlei de elite',
            icon: Icons.workspace_premium,
            color: Color(0xFFF4A261),
          ),
          SportBadge(
            id: 'b3',
            label: 'Hooper',
            icon: Icons.sports_basketball,
            color: Color(0xFF1F3A8A),
          ),
        ],
        friends: <UserSummary>[
          for (int i = 0; i < 6; i++)
            UserSummary(
              id: 'f_$i',
              name: 'Amigo ${i + 1}',
              handle: '@amigo${i + 1}',
              avatarUrl: AppAssets.avatar('A${i + 1}'),
            ),
        ],
        rating: const RatingSummary(
          average: 4.8,
          count: 12,
          breakdown: <int, double>{5: 0.70, 4: 0.20, 3: 0.05, 2: 0.03, 1: 0.01},
        ),
        gallery: const <String>[
          AppAssets.galleryTeamPhoto,
          AppAssets.galleryTeamPhoto,
          AppAssets.galleryTeamPhoto,
        ],
      );
}
