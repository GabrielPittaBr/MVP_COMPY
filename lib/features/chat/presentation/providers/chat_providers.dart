import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/in_memory_chat_store.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_conversation.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/mark_conversation_as_read.dart';
import '../../domain/usecases/open_conversation.dart';
import '../../domain/usecases/watch_conversations.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? ChatRemoteDataSource(FirebaseFirestore.instance) : null,
);

/// Identidade de quem está usando o app: vai no `senderId` da mensagem e
/// decide de que lado o balão cai.
///
/// Sem Firebase (`kUseFirebaseRepos = false`) cai no usuário mockado do
/// `InMemoryChatStore`, que é quem assina as conversas de exemplo. Com Firebase
/// ligado e ninguém logado devolve `null`: é melhor recusar o envio do que
/// gravar identidade falsa — que é justamente o que as regras do Firestore
/// rejeitam (`senderId == request.auth.uid`).
final currentUserIdProvider = Provider<String?>((ref) {
  if (!kUseFirebaseRepos) return InMemoryChatStore.currentUserId;
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(
    ref.watch(chatRemoteDataSourceProvider),
    currentUserId: ref.watch(currentUserIdProvider),
  ),
);

final getConversationsProvider = Provider<GetConversations>(
  (ref) => GetConversations(ref.watch(chatRepositoryProvider)),
);

final watchConversationsProvider = Provider<WatchConversations>(
  (ref) => WatchConversations(ref.watch(chatRepositoryProvider)),
);

final getConversationProvider = Provider<GetConversation>(
  (ref) => GetConversation(ref.watch(chatRepositoryProvider)),
);

final watchMessagesProvider = Provider<WatchMessages>(
  (ref) => WatchMessages(ref.watch(chatRepositoryProvider)),
);

final sendMessageProvider = Provider<SendMessage>(
  (ref) => SendMessage(ref.watch(chatRepositoryProvider)),
);

final openConversationProvider = Provider<OpenConversation>(
  (ref) => OpenConversation(ref.watch(chatRepositoryProvider)),
);

final markConversationAsReadProvider = Provider<MarkConversationAsRead>(
  (ref) => MarkConversationAsRead(ref.watch(chatRepositoryProvider)),
);

/// Lista paginada de conversas — blocos de 10 via `startAfterDocument`.
/// Use `loadMore()` no scroll e `ref.invalidate` para recarregar.
class PaginatedConversationsController extends AsyncNotifier<List<Conversation>> {
  static const int pageSize = 10;

  String? _userId;
  Object? _cursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<Conversation>> build() async {
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    // Reage a login/logout: trocar de usuário refaz a primeira página. Passa
    // pelo `currentUserIdProvider` para o modo sem Firebase também ter
    // identidade — com o uid cru a lista mockada vinha sempre vazia.
    _userId = ref.watch(currentUserIdProvider);
    final userId = _userId;
    if (userId == null) {
      _hasMore = false;
      return const <Conversation>[];
    }
    final page = await ref
        .watch(getConversationsProvider)
        .call(userId, pageSize: pageSize);
    _cursor = page.cursor;
    _hasMore = page.hasMore;

    // Só o topo da lista fica ao vivo. É dele que saem o preview da última
    // mensagem e o contador de não-lidas, que mudam sozinhos quando chega
    // mensagem — antes o badge só aparecia depois de puxar para atualizar.
    // As páginas seguintes seguem pontuais: histórico antigo não se mexe.
    final subscription = ref
        .watch(watchConversationsProvider)
        .call(userId, limit: pageSize)
        .listen(_mergeFirstPage);
    ref.onDispose(subscription.cancel);

    return page.items;
  }

  /// Troca a primeira página pela versão ao vivo, preservando o que o scroll
  /// já trouxe abaixo dela.
  void _mergeFirstPage(List<Conversation> live) {
    final loaded = state.valueOrNull;
    // Ainda construindo: a primeira página vem do `build`, não daqui.
    if (loaded == null) return;

    final liveIds = <String>{for (final c in live) c.id};
    state = AsyncData<List<Conversation>>(<Conversation>[
      ...live,
      for (final c in loaded)
        if (!liveIds.contains(c.id)) c,
    ]);
  }

  /// Zera as não-lidas de uma conversa na lista já carregada.
  ///
  /// Espelha localmente a escrita que a sala acabou de fazer. Recarregar a
  /// lista inteira só para apagar um badge custaria uma página de leituras e
  /// jogaria o usuário de volta ao topo da paginação.
  void markReadLocally(String conversationId) {
    final current = state.valueOrNull;
    if (current == null) return;

    var changed = false;
    final updated = <Conversation>[];
    for (final c in current) {
      if (c.id == conversationId && c.unreadCount != 0) {
        changed = true;
        updated.add(c.copyWith(unreadCount: 0));
      } else {
        updated.add(c);
      }
    }
    if (changed) state = AsyncData<List<Conversation>>(updated);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final userId = _userId;
    if (current == null || userId == null || _isLoadingMore || !_hasMore) {
      return;
    }
    _isLoadingMore = true;
    try {
      final page = await ref
          .read(getConversationsProvider)
          .call(userId, cursor: _cursor, pageSize: pageSize);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      state = AsyncData<List<Conversation>>(
        <Conversation>[...current, ...page.items],
      );
    } finally {
      _isLoadingMore = false;
    }
  }
}

final paginatedConversationsProvider =
    AsyncNotifierProvider<PaginatedConversationsController, List<Conversation>>(
  PaginatedConversationsController.new,
);

final conversationMessagesProvider =
    StreamProvider.family<List<Message>, String>(
  (ref, conversationId) =>
      ref.watch(watchMessagesProvider).call(conversationId),
);

/// A conversa que a sala está exibindo.
///
/// Antes a sala garimpava o peer na lista paginada já carregada e estourava
/// quando não achava — bastava abrir a sala com a lista ainda carregando.
/// Aqui ela se resolve sozinha: aproveita a lista quando a conversa já está
/// nela e, senão, lê o documento avulso. Devolve `null` quando a conversa não
/// existe ou não é do usuário.
final conversationProvider =
    FutureProvider.family<Conversation?, String>((ref, conversationId) async {
  final loaded = ref.watch(paginatedConversationsProvider).valueOrNull;
  for (final c in loaded ?? const <Conversation>[]) {
    if (c.id == conversationId) return c;
  }

  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(getConversationProvider).call(conversationId, userId);
});
