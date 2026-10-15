import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';
import 'package:mvp_compy/features/chat/domain/entities/message.dart';
import 'package:mvp_compy/features/chat/domain/repositories/chat_repository.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/chat/presentation/widgets/share_place_sheet.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

void main() {
  // `network-request-failed` é o código que a criação de evento já tratava
  // como offline; o compartilhamento passou a reconhecer o mesmo conjunto.
  for (final code in <String>['unavailable', 'network-request-failed']) {
    testWidgets('offline ($code) keeps share sheet open and asks to reconnect',
        (tester) async {
      const peer = UserSummary(
        id: 'peer',
        name: 'Pessoa',
        handle: '@pessoa',
        avatarUrl: '',
      );
      final conversation = Conversation(
        id: 'conversation',
        peer: peer,
        lastMessage: '',
        unreadCount: 0,
        lastMessageAt: DateTime(2026),
      );
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SharePlaceSheet.show(context, 'place-1'),
                  child: const Text('Abrir compartilhamento'),
                ),
              ),
            ),
          ),
          GoRoute(path: '/chat/:id', builder: (_, __) => const Text('Chat')),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider
                .overrideWithValue(_OfflineChatRepository(code)),
            paginatedConversationsProvider.overrideWith(
              () => _StaticConversationsController(conversation),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Abrir compartilhamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('Enviar para'), findsOneWidget);
      expect(find.textContaining('Reconecte-se à internet'), findsOneWidget);
      expect(find.text('Encaminhou um local...'), findsNothing);
    });
  }
}

class _StaticConversationsController extends PaginatedConversationsController {
  _StaticConversationsController(this.conversation);

  final Conversation conversation;

  @override
  Future<List<Conversation>> build() async => <Conversation>[conversation];
}

class _OfflineChatRepository implements ChatRepository {
  _OfflineChatRepository(this.code);

  final String code;

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String peerId,
    required String text,
    String? placeId,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: code,
      message: 'offline',
    );
  }

  @override
  Future<PagedResult<Conversation>> fetchConversationsPage(
    String userId, {
    Object? cursor,
    int pageSize = 10,
  }) =>
      throw UnimplementedError();

  @override
  Stream<List<Conversation>> watchConversationsFirstPage(
    String userId, {
    int limit = 10,
  }) =>
      throw UnimplementedError();

  @override
  Future<Conversation?> fetchConversation(
          String conversationId, String userId) =>
      throw UnimplementedError();

  @override
  Future<String> openConversationWith({
    required UserSummary me,
    required UserSummary peer,
  }) =>
      throw UnimplementedError();

  @override
  Stream<List<Message>> watchMessages(String conversationId) =>
      throw UnimplementedError();

  @override
  Future<void> markAsRead(String conversationId) => throw UnimplementedError();
}
