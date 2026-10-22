import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/user_avatar.dart';

/// Lista rolável: nome e avatar de todos os participantes continuam acessíveis.
class ParticipantsAvatars extends StatelessWidget {
  const ParticipantsAvatars({
    required this.participants,
    super.key,
  });

  final List<UserSummary> participants;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final user = participants[index];
          return ActionChip(
            avatar: UserAvatar(user: user, radius: 16),
            label: Text(user.name),
            backgroundColor: AppColors.surfaceMuted,
            onPressed: () => context.push(AppRoutes.publicProfileFor(user.id)),
          );
        },
      ),
    );
  }
}
