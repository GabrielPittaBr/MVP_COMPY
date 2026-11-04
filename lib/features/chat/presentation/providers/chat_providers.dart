import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/in_memory_chat_store.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_conversation.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/get_older_messages.dart';
import '../../domain/usecases/mark_conversation_as_read.dart';
import '../../domain/usecases/open_conversation.dart';
import '../../domain/usecases/watch_conversations.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource?>(
  (ref) => kUseFirebaseRepos
      ? ChatRemoteDataSource(FirebaseFirestore.instance)
      : null,
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

final getOlderMessagesProvider = Provider<GetOlderMessages>(
  (ref) => GetOlderMessages(ref.watch(chatRepositoryProvider)),
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

/// Identidade atual para apresentação, sem alterar o snapshot da conversa.
/// Lista e sala compartilham publicUserSummaryProvider pelo UID; os balões
/// recebem o resultado da sala, sem assinaturas por mensagem. Sem um perfil
/// atual disponível, usamos o snapshot como fallback. Foto vazia
/// em um perfil existente é remoção, nunca motivo para recuperar a antiga.
final conversationPeerProvider =
    Provider.autoDispose.family<UserSummary, UserSummary>((ref, snapshot) {
  if (snapshot.id.isEmpty || snapshot.id == 'unknown') return snapshot;
  return ref.watch(publicUserSummaryProvider(snapshot.id)).valueOrNull ??
      snapshot;
});

/// Lista paginada de conversas — blocos de 10 via `startAfterDocument`.
/// Use `loadMore()` no scroll e `ref.invalidate` para recarregar.
class PaginatedConversationsController
    extends AsyncNotifier<List<Conversation>> {
  static const int pageSize = 10;

  String? _userId;
  Object? _cursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;

  /// Se o scroll já trouxe alguma página além da primeira.
  bool _loadedMore = false;

  bool get hasMore => _hasMore;
  bool get loadMoreFailed => _loadMoreFailed;

  @override
  Future<List<Conversation>> build() {
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    _loadMoreFailed = false;
    _loadedMore = false;
    // Reage a login/logout: trocar de usuário refaz a primeira página. Passa
    // pelo `currentUserIdProvider` para o modo sem Firebase também ter
    // identidade — com o uid cru a lista mockada vinha sempre vazia.
    _userId = ref.watch(currentUserIdProvider);
    final userId = _userId;
    if (userId == null) {
      _hasMore = false;
      return Future<List<Conversation>>.value(const <Conversation>[]);
    }

    // Só o topo da lista fica ao vivo. É dele que saem o preview da última
    // mensagem e o contador de não-lidas, que mudam sozinhos quando chega
    // mensagem — antes o badge só aparecia depois de puxar para atualizar.
    // As páginas seguintes seguem pontuais: histórico antigo não se mexe.
    //
    // A primeira emissão do listener já é a primeira página. Antes um `get`
    // lia as mesmas 10 conversas e o listener lia tudo de novo em seguida.
    final firstPage = Completer<List<Conversation>>();
    final subscription = ref
        .watch(watchConversationsProvider)
        .call(userId, limit: pageSize)
        .listen(
      (page) {
        // Até o scroll trazer a 2ª página, o cursor acompanha a janela ao
        // vivo: a 1ª emissão pode vir do cache com menos conversas que o
        // servidor, e um `hasMore` falso ali travaria a paginação.
        if (!_loadedMore) {
          _cursor = page.cursor;
          _hasMore = page.hasMore;
        }
        if (firstPage.isCompleted) {
          _mergeFirstPage(page.items);
        } else {
          firstPage.complete(page.items);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // Depois da primeira página, a lista já carregada continua na tela.
        if (!firstPage.isCompleted) firstPage.completeError(error, stackTrace);
      },
    );
    ref.onDispose(subscription.cancel);

    return firstPage.future;
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
    _loadMoreFailed = false;
    state = AsyncData<List<Conversation>>(<Conversation>[...current]);
    try {
      final page = await ref
          .read(getConversationsProvider)
          .call(userId, cursor: _cursor, pageSize: pageSize);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _loadedMore = true;
      // Uma conversa que desceu da janela ao vivo já está na lista e pode
      // voltar nesta página.
      final loadedIds = <String>{for (final c in current) c.id};
      state = AsyncData<List<Conversation>>(<Conversation>[
        ...current,
        for (final c in page.items)
          if (!loadedIds.contains(c.id)) c,
      ]);
    } catch (_) {
      // A página já carregada continua utilizável. O rodapé permite repetir
      // sem reiniciar a lista nem gerar uma exceção não tratada no scroll.
      _loadMoreFailed = true;
      state = AsyncData<List<Conversation>>(<Conversation>[...current]);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final paginatedConversationsProvider =
    AsyncNotifierProvider<PaginatedConversationsController, List<Conversation>>(
  PaginatedConversationsController.new,
);

/// Mensagens da sala, paginadas: só as [pageSize] mais recentes ficam ao
/// vivo; as anteriores chegam de [pageSize] em [pageSize], com leitura
/// pontual, quando o usuário rola até o topo. Antes a sala ouvia o histórico
/// inteiro e o listener seguia aberto depois de sair dela.
///
/// Entrega da mais antiga para a mais recente, a ordem do `buildChatTimeline`.
class PaginatedMessagesController
    extends AutoDisposeFamilyStreamNotifier<List<Message>, String> {
  static const int pageSize = 20;

  /// Tudo o que já chegou, por id: a janela ao vivo e as páginas antigas se
  /// juntam aqui. Mensagem que sai da janela ao vivo continua na tela.
  final Map<String, Message> _byId = <String, Message>{};
  Object? _cursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;

  bool get hasMore => _hasMore;
  bool get loadMoreFailed => _loadMoreFailed;

  @override
  Stream<List<Message>> build(String conversationId) {
    _byId.clear();
    _cursor = null;
    _hasMore = false;
    _isLoadingMore = false;
    _loadMoreFailed = false;
    return ref
        .watch(watchMessagesProvider)
        .call(conversationId, limit: pageSize)
        .map(_mergeLive);
  }

  List<Message> _mergeLive(PagedResult<Message> live) {
    for (final m in live.items) {
      _byId[m.id] = m;
    }
    final merged = _sorted();
    // A janela só anda para frente. O cursor vem dela enquanto ela tiver a
    // mais antiga carregada: na primeira emissão, ou quando a do cache chega
    // menor que a do servidor. Depois que ela anda, ou que o scroll trouxe
    // páginas antigas, o cursor fica onde está.
    if (merged.isEmpty || merged.first.id == live.items.firstOrNull?.id) {
      _cursor = live.cursor;
      _hasMore = live.hasMore;
    }
    return merged;
  }

  List<Message> _sorted() =>
      _byId.values.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));

  /// Anexa a página anterior à mais antiga carregada. Em falha, o que já está
  /// na tela fica e [loadMoreFailed] libera o "tentar de novo".
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (state.valueOrNull == null ||
        cursor == null ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }
    _isLoadingMore = true;
    _loadMoreFailed = false;
    state = AsyncData<List<Message>>(_sorted());
    try {
      final page = await ref
          .read(getOlderMessagesProvider)
          .call(arg, cursor: cursor, pageSize: pageSize);
      // A versão ao vivo de uma mensagem vale mais que a da página.
      for (final m in page.items) {
        _byId.putIfAbsent(m.id, () => m);
      }
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (_) {
      _loadMoreFailed = true;
    } finally {
      _isLoadingMore = false;
    }
    state = AsyncData<List<Message>>(_sorted());
  }
}

final paginatedMessagesProvider = AutoDisposeStreamNotifierProviderFamily<
    PaginatedMessagesController, List<Message>, String>(
  PaginatedMessagesController.new,
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
