import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/secondary_button.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.summary, super.key});

  final UserSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        CircleAvatar(
          radius: 56,
          backgroundColor: AppColors.surfaceMuted,
          backgroundImage: CachedNetworkImageProvider(summary.avatarUrl),
        ),
        const SizedBox(height: 12),
        Text(
          summary.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        Text(
          summary.handle,
          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SecondaryButton(label: AppStrings.profileEdit, onPressed: () {}),
      ],
    );
  }
}
