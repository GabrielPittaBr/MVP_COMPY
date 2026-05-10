import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';

/// Pilha sobreposta de avatares dos participantes (mockup "3.1 Evento detalhes").
class ParticipantsAvatars extends StatelessWidget {
  const ParticipantsAvatars({
    required this.participants,
    this.maxVisible = 7,
    super.key,
  });

  final List<UserSummary> participants;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = participants.take(maxVisible).toList();
    return SizedBox(
      height: 36,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * 24.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceMuted,
                  backgroundImage: CachedNetworkImageProvider(visible[i].avatarUrl),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
