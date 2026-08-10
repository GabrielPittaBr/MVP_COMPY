import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/message.dart';
import 'peer_avatar.dart';
import 'place_message_card.dart';

/// Balão de mensagem alinhado conforme [isMine].
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.peer,
    super.key,
  });

  final Message message;
  final bool isMine;

  /// Pode ser nulo enquanto a conversa ainda está sendo resolvida — o balão
  /// desenha o avatar genérico em vez de derrubar a tela.
  final UserSummary? peer;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (!isMine) ...<Widget>[
            PeerAvatar(peer: peer, radius: 14),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: message.isPlace
                      ? PlaceMessageCard(
                          placeId: message.placeId!,
                          isMine: isMine,
                        )
                      : Text(
                          message.text,
                          style: TextStyle(
                            color: isMine ? Colors.white : AppColors.onSurface,
                            fontSize: 14,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    timeFormat.format(message.sentAt),
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
