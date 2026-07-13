import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/in_memory_chat_store.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote);
  final ChatRemoteDataSource? _remote;

  @override
  Future<PagedResult<Conversation>> fetchConversationsPage(
    String userId, {
    Object? cursor,
    int pageSize = 10,
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      // Mock: o cursor é o offset na lista em memória.
      final all = InMemoryChatStore.instance.conversationsSnapshot;
      final offset = (cursor as int?) ?? 0;
      final items = all.skip(offset).take(pageSize).toList();
      final nextOffset = offset + items.length;
      return PagedResult<Conversation>(
        items: items,
        cursor: nextOffset,
        hasMore: nextOffset < all.length,
      );
    }

    final snapshot = await _remote.fetchConversationsPage(
      userId,
      startAfter: cursor as DocumentSnapshot<Map<String, dynamic>>?,
      limit: pageSize,
    );
    final items = snapshot.docs
        .map((doc) => _conversationFromDoc(userId, doc))
        .toList();
    return PagedResult<Conversation>(
      items: items,
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : cursor,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Mapeia `conversations/{id}` para a entidade, resolvendo o peer
  /// (o membro que não é o usuário corrente) via `memberSummaries`.
  ///
  /// Formato esperado do documento:
  /// ```
  /// members: [uidA, uidB]
  /// memberSummaries: { uidA: {UserSummary}, uidB: {UserSummary} }
  /// lastMessage: String, lastMessageAt: Timestamp
  /// unreadCounts: { uid: int } (opcional)
  /// ```
  Conversation _conversationFromDoc(
    String userId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final summaries =
        (data['memberSummaries'] as Map<String, dynamic>?) ?? const {};

    UserSummary peer = const UserSummary(
      id: 'unknown',
      name: 'Desconhecido',
      handle: '@unknown',
      avatarUrl: '',
    );
    for (final entry in summaries.entries) {
      if (entry.key != userId) {
        peer = UserSummary.fromMap(entry.value);
        break;
      }
    }

    final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
    return Conversation(
      id: doc.id,
      peer: peer,
      lastMessage: (data['lastMessage'] as String?) ?? '',
      unreadCount: (unreadCounts?[userId] as int?) ?? 0,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    if (!kUseFirebaseRepos) {
      return InMemoryChatStore.instance.watchMessages(conversationId);
    }
    return const Stream<List<Message>>.empty();
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    if (!kUseFirebaseRepos) {
      InMemoryChatStore.instance.sendMessage(
        conversationId: conversationId,
        text: text,
      );
      return;
    }
    return _remote!.sendMessage(
      conversationId: conversationId,
      senderId: InMemoryChatStore.currentUserId,
      text: text,
    );
  }
}
