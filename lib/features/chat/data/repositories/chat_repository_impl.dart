import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/user_summary.dart';
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
  Stream<PagedResult<Conversation>> watchConversationsFirstPage(
    String userId, {
    int limit = 10,
  }) {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryChatStore.instance.watchConversations().map(
            (all) => PagedResult<Conversation>(
              items: all.take(limit).toList(),
              cursor: all.length < limit ? all.length : limit,
              hasMore: all.length > limit,
            ),
          );
    }
    return _remote.watchConversationsFirstPage(userId, limit: limit).map(
          (snapshot) => PagedResult<Conversation>(
            items: snapshot.docs
                .map((doc) =>
                    ConversationMapper.fromMap(doc.id, doc.data(), userId))
                .toList(),
            cursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
            hasMore: snapshot.docs.length == limit,
          ),
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
  Future<String> openConversationWith({
    required UserSummary me,
    required UserSummary peer,
  }) async {
    final conversationId = Conversation.idBetween(me.id, peer.id);

    if (!kUseFirebaseRepos || _remote == null) {
      InMemoryChatStore.instance.ensureConversation(
        id: conversationId,
        peer: peer,
      );
      return conversationId;
    }

    // Confirmar a ausência antes de criar não é zelo: o `set` de criação
    // sobre uma conversa que já existe **passa** pelas regras quando membros e
    // resumos chegam idênticos (o `diff()` não acusa campo cujo valor não
    // mudou) e zeraria `lastMessage` e `unreadCounts` da conversa em uso.
    //
    // Como o id vem dos dois uids, uma conversa existente nesse id é
    // necessariamente minha — logo, ler devolve a conversa em vez de null.
    final existing = await fetchConversation(conversationId, me.id);
    if (existing != null) return conversationId;

    await _remote.createConversation(
      conversationId: conversationId,
      memberSummaries: <String, dynamic>{
        me.id: me.toMap(),
        peer.id: peer.toMap(),
      },
    );
    return conversationId;
  }

  @override
  Stream<PagedResult<Message>> watchRecentMessages(
    String conversationId, {
    int limit = 20,
  }) {
    if (!kUseFirebaseRepos || _remote == null) {
      // Mock: o cursor é o índice da mais antiga da janela na lista em
      // memória, que só cresce no fim — o índice não muda com mensagem nova.
      return InMemoryChatStore.instance.watchMessages(conversationId).map(
        (all) {
          final start = all.length > limit ? all.length - limit : 0;
          return PagedResult<Message>(
            items: all.sublist(start),
            cursor: start,
            hasMore: start > 0,
          );
        },
      );
    }
    return _remote
        .watchRecentMessages(conversationId, limit: limit)
        .map((snapshot) => _messagesPage(conversationId, snapshot, limit));
  }

  @override
  Future<PagedResult<Message>> fetchOlderMessages(
    String conversationId, {
    required Object cursor,
    int pageSize = 20,
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      final all = InMemoryChatStore.instance.messagesSnapshot(conversationId);
      final end = cursor as int;
      final start = end > pageSize ? end - pageSize : 0;
      return PagedResult<Message>(
        items: all.sublist(start, end),
        cursor: start,
        hasMore: start > 0,
      );
    }
    final snapshot = await _remote.fetchMessagesBefore(
      conversationId,
      startAfter: cursor as DocumentSnapshot<Map<String, dynamic>>,
      limit: pageSize,
    );
    return _messagesPage(conversationId, snapshot, pageSize);
  }

  /// A consulta vem da mais recente para a mais antiga; a sala quer o
  /// contrário. O cursor é o último documento — o mais antigo da página.
  PagedResult<Message> _messagesPage(
    String conversationId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final messages = snapshot.docs
        .map((doc) => MessageMapper.fromMap(doc.id, conversationId, doc.data()))
        .toList();
    return PagedResult<Message>(
      items: MessageMapper.sortedBySentAt(messages),
      cursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String peerId,
    required String text,
    String? placeId,
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      InMemoryChatStore.instance.sendMessage(
        conversationId: conversationId,
        text: text,
        placeId: placeId,
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
      peerId: peerId,
      text: text,
      placeId: placeId,
    );
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    if (!kUseFirebaseRepos || _remote == null) {
      InMemoryChatStore.instance.markAsRead(conversationId);
      return;
    }
    final userId = _currentUserId;
    if (userId == null) return;
    await _remote.markAsRead(conversationId: conversationId, userId: userId);
  }
}
