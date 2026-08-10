import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/conversation.dart';

/// Converte `conversations/{id}` para [Conversation], resolvendo o peer
/// (o membro que não é o usuário corrente) via `memberSummaries`.
///
/// Trabalha sobre o mapa cru, e não sobre o snapshot, para servir aos dois
/// caminhos: a consulta paginada da lista e a leitura avulsa que a sala faz
/// quando a conversa não está na página já carregada.
///
/// Formato esperado do documento:
/// ```
/// members: [uidA, uidB]
/// memberSummaries: { uidA: {UserSummary}, uidB: {UserSummary} }
/// lastMessage: String, lastMessageAt: Timestamp
/// unreadCounts: { uid: int } (opcional)
/// ```
abstract final class ConversationMapper {
  static const UserSummary unknownPeer = UserSummary(
    id: 'unknown',
    name: 'Desconhecido',
    handle: '@unknown',
    avatarUrl: '',
  );

  static Conversation fromMap(
    String id,
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    final summaries =
        (data['memberSummaries'] as Map<String, dynamic>?) ?? const {};

    UserSummary peer = unknownPeer;
    for (final entry in summaries.entries) {
      if (entry.key != currentUserId) {
        peer = UserSummary.fromMap(entry.value);
        break;
      }
    }

    final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
    return Conversation(
      id: id,
      peer: peer,
      lastMessage: (data['lastMessage'] as String?) ?? '',
      unreadCount: (unreadCounts?[currentUserId] as int?) ?? 0,
      // Conversa recém-criada ainda não tem o `serverTimestamp()` de volta:
      // o horário local a mantém no topo da lista, onde ela de fato pertence.
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
