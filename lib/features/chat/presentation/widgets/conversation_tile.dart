import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/conversation.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conversation,
    required this.onTap,
    super.key,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(conversation.peer.avatarUrl),
      ),
      title: Text(
        conversation.peer.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Row(
        children: <Widget>[
          const Icon(Icons.reply, size: 14, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.onSurfaceMuted),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const Text(
            AppStrings.chatToday,
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
