import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/day_label.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/conversation.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conversation,
    required this.onTap,
    this.now,
    super.key,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final DateTime? now;

  static String timeLabel(DateTime sentAt, DateTime reference) {
    final localSentAt = sentAt.toLocal();
    final localReference = reference.toLocal();
    if (DayLabel.isSameDay(localSentAt, localReference)) {
      return DateFormat('HH:mm').format(localSentAt);
    }
    final yesterday = DateTime(
      localReference.year,
      localReference.month,
      localReference.day - 1,
    );
    if (DayLabel.isSameDay(localSentAt, yesterday)) {
      return AppStrings.chatYesterday;
    }
    return DateFormat('dd/MM/yy').format(localSentAt);
  }

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount > 0;
    return Material(
      color: unread
          ? AppColors.primary.withValues(alpha: 0.045)
          : AppColors.surface,
      child: InkWell(
        key: Key('conversation-${conversation.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: <Widget>[
              UserAvatar(user: conversation.peer, radius: 27),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            conversation.peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel(conversation.lastMessageAt,
                              now ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                            color: unread
                                ? AppColors.primary
                                : AppColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            conversation.lastMessage.isEmpty
                                ? AppStrings.chatNoMessages
                                : conversation.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: unread
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceMuted,
                            ),
                          ),
                        ),
                        if (unread) ...<Widget>[
                          const SizedBox(width: 10),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              AppStrings.chatUnreadCount(
                                  conversation.unreadCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
