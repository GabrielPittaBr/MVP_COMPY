import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? ChatRemoteDataSource(FirebaseFirestore.instance) : null,
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(ref.watch(chatRemoteDataSourceProvider)),
);

final getConversationsProvider = Provider<GetConversations>(
  (ref) => GetConversations(ref.watch(chatRepositoryProvider)),
);

final watchMessagesProvider = Provider<WatchMessages>(
  (ref) => WatchMessages(ref.watch(chatRepositoryProvider)),
);

final sendMessageProvider = Provider<SendMessage>(
  (ref) => SendMessage(ref.watch(chatRepositoryProvider)),
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
    // Reage a login/logout: trocar de usuário refaz a primeira página.
    _userId = ref.watch(authStateProvider).valueOrNull?.uid;
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
    return page.items;
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
