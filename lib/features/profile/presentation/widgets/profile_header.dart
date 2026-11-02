import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/user_avatar.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.summary,
    required this.onEdit,
    super.key,
  });

  final UserSummary summary;

  /// Abre a edição do perfil.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        UserAvatar(user: summary, radius: 56),
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
        SecondaryButton(label: AppStrings.profileEdit, onPressed: onEdit),
      ],
    );
  }
}
