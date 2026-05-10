import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';

class FriendsAvatars extends StatelessWidget {
  const FriendsAvatars({required this.friends, super.key});
  final List<UserSummary> friends;

  @override
  Widget build(BuildContext context) {
    final visible = friends.take(6).toList();
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
                  backgroundImage: CachedNetworkImageProvider(visible[i].avatarUrl),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
