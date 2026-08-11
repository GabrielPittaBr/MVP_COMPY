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

  Conversation copyWith({
    String? lastMessage,
    int? unreadCount,
    DateTime? lastMessageAt,
  }) {
    return Conversation(
      id: id,
      peer: peer,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  /// Identidade determinística da conversa 1:1 entre [a] e [b].
  ///
  /// Os uids são ordenados antes de virar o id do documento, então os dois
  /// lados chegam sempre no mesmo lugar. Sem isso, dois toques seguidos — ou
  /// os dois participantes iniciando ao mesmo tempo — criariam conversas
  /// distintas com a mesma pessoa, duplicando-a na lista e partindo o
  /// histórico entre os documentos.
  static String idBetween(String a, String b) {
    if (a.isEmpty || b.isEmpty) {
      throw ArgumentError('Conversa exige dois uids não vazios.');
    }
    if (a == b) {
      throw ArgumentError('Não existe conversa de alguém consigo mesmo.');
    }
    final members = <String>[a, b]..sort();
    return '${members.first}_${members.last}';
  }

  @override
  List<Object?> get props => <Object?>[id, peer, lastMessage, unreadCount, lastMessageAt];
}
