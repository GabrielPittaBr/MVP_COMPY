import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/conversation.dart';

/// Converte `conversations/{id}` para [Conversation], resolvendo o peer
/// (o membro que não é o usuário corrente) por UID em `members`.
/// `memberSummaries` é um snapshot histórico e fallback de apresentação.
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
  /// Conversa sem `memberSummaries` legível — a lista precisa desenhar algo.
  static const UserSummary unknownPeer = UserSummary(
    id: 'unknown',
    name: AppStrings.chatUnknownPeer,
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

    // O UID vem dos membros, nunca do id embutido no resumo. Mesmo sem
    // resumo, uma conversa legada ainda pode consultar o perfil atual.
    // Documentos sem members usam a chave histórica como último recurso.
    final members = data['members'];
    final peerIds =
        members is List ? members.whereType<String>() : summaries.keys;
    UserSummary peer = unknownPeer;
    for (final uid in peerIds) {
      if (uid.isNotEmpty && uid != currentUserId) {
        final raw = summaries[uid];
        final summary = raw is Map ? raw : const <String, dynamic>{};
        peer = UserSummary(
          id: uid,
          name: summary['name'] is String
              ? summary['name'] as String
              : unknownPeer.name,
          handle: summary['handle'] is String
              ? summary['handle'] as String
              : unknownPeer.handle,
          avatarUrl: summary['avatarUrl'] is String
              ? summary['avatarUrl'] as String
              : '',
        );
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
