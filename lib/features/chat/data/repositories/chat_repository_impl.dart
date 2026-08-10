import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/paged_result.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/in_memory_chat_store.dart';
import '../mappers/conversation_mapper.dart';
import '../mappers/message_mapper.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote, {String? currentUserId})
      : _currentUserId = currentUserId;

  final ChatRemoteDataSource? _remote;

  /// Uid de quem está usando o app. Nulo quando ninguém está logado — nesse
  /// caso o envio é recusado em vez de gravar identidade falsa.
  final String? _currentUserId;

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
        .map((doc) => ConversationMapper.fromMap(doc.id, doc.data(), userId))
        .toList();
    return PagedResult<Conversation>(
      items: items,
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : cursor,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  @override
  Future<Conversation?> fetchConversation(
    String conversationId,
    String userId,
  ) async {
    if (!kUseFirebaseRepos || _remote == null) {
      for (final c in InMemoryChatStore.instance.conversationsSnapshot) {
        if (c.id == conversationId) return c;
      }
      return null;
    }

    try {
      final doc = await _remote.fetchConversation(conversationId);
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return ConversationMapper.fromMap(doc.id, data, userId);
    } on FirebaseException catch (e) {
      // Conversa alheia não é "erro do app": as regras recusam a leitura de
      // quem não está em `members`, e para a sala isso é o mesmo que não
      // existir. Qualquer outra falha (rede, indisponibilidade) sobe.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryChatStore.instance.watchMessages(conversationId);
    }
    return _remote.watchMessages(conversationId).map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => MessageMapper.fromMap(doc.id, conversationId, doc.data()))
          .toList();
      return MessageMapper.sortedBySentAt(messages);
    });
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      InMemoryChatStore.instance.sendMessage(
        conversationId: conversationId,
        text: text,
      );
      return;
    }
    final senderId = _currentUserId;
    if (senderId == null) {
      // As regras do Firestore exigem `senderId == request.auth.uid`; enviar
      // sem uid seria gravar identidade falsa e levar PERMISSION_DENIED.
      throw StateError('Não há usuário autenticado para enviar a mensagem.');
    }
    return _remote.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      text: text,
    );
  }
}
