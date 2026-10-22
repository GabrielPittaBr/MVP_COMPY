import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/user_summary.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, this.radius = 20, super.key});

  final UserSummary? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = user?.avatarUrl ?? '';
    final uri = Uri.tryParse(url);
    final valid = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: radius, color: AppColors.onSurfaceMuted),
    );
    return ClipOval(
      child: valid
          ? CachedNetworkImage(
              imageUrl: url,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }
}
