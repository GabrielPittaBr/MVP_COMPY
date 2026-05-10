import 'package:equatable/equatable.dart';

import '../../../../shared/models/user_summary.dart';

/// Conversa privada entre o usuário corrente e um par.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.unreadCount,
    required this.lastMessageAt,
  });

  final String id;
  final UserSummary peer;
  final String lastMessage;
  final int unreadCount;
  final DateTime lastMessageAt;

  @override
  List<Object?> get props => <Object?>[id, peer, lastMessage, unreadCount, lastMessageAt];
}
