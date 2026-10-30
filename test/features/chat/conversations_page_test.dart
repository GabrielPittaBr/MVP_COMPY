import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';
import 'package:mvp_compy/features/chat/domain/repositories/chat_repository.dart';
import 'package:mvp_compy/features/chat/presentation/pages/conversations_page.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/chat/presentation/widgets/conversation_tile.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

Conversation _conversation(int index, {int unread = 0}) => Conversation(
      id: 'c$index',
      peer: UserSummary(
        id: 'u$index',
        name: 'Pessoa $index',
        handle: '@p$index',
        avatarUrl: '',
      ),
      lastMessage: 'Vamos jogar $index?',
      unreadCount: unread,
      lastMessageAt: DateTime(2026, 10, 26, 14, index % 60),
    );

class _ChatRepository implements ChatRepository {
  _ChatRepository(this.conversations);

  final List<Conversation> conversations;
  Completer<void>? firstPageGate;
  bool fail = false;
  bool failMore = false;
  int fetchCalls = 0;
  final cursors = <Object?>[];

  @override
  Future<PagedResult<Conversation>> fetchConversationsPage(
    String userId, {
    Object? cursor,
    int pageSize = 10,
  }) async {
    fetchCalls++;
    cursors.add(cursor);
    if (cursor == null) await firstPageGate?.future;
    if (fail || (cursor != null && failMore)) throw StateError('sem rede');
    final start = (cursor as int?) ?? 0;
    final page = conversations.skip(start).take(pageSize).toList();
    final end = start + page.length;
    return PagedResult<Conversation>(
      items: page,
      cursor: end,
      hasMore: end < conversations.length,
    );
  }

  @override
  Stream<List<Conversation>> watchConversationsFirstPage(
    String userId, {
    int limit = 10,
  }) =>
      Stream<List<Conversation>>.value(conversations.take(limit).toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(GoRouter, ProviderContainer)> _open(
  WidgetTester tester,
  _ChatRepository repository, {
  bool settle = true,
  Size size = const Size(390, 760),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: <Override>[
    currentUserIdProvider.overrideWithValue('me'),
    chatRepositoryProvider.overrideWithValue(repository),
    publicUserSummaryProvider.overrideWith((ref, uid) => Stream.value(null)),
  ]);
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: AppRoutes.chat,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.chat,
        builder: (_, __) => const ConversationsPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'nova',
            builder: (_, __) => const Scaffold(body: Text('nova conversa')),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => Scaffold(
              body: Text('sala ${state.pathParameters['id']}'),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  if (settle) await tester.pumpAndSettle();
  return (router, container);
}

void main() {
  testWidgets('vazio mostra ilustração, orientação e ação única',
      (tester) async {
    final repository = _ChatRepository(<Conversation>[]);
    await _open(tester, repository, size: const Size(280, 480));
    expect(find.text(AppStrings.chatEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.chatEmptyHint), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
    expect(find.text(AppStrings.chatStartConversation), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 2);
  });

  testWidgets('ação do vazio abre a rota existente de nova conversa',
      (tester) async {
    await _open(tester, _ChatRepository(<Conversation>[]));
    await tester.tap(find.text(AppStrings.chatStartConversation));
    await tester.pumpAndSettle();
    expect(find.text('nova conversa'), findsOneWidget);
  });

  testWidgets('lista mostra prévia, badge e abre conversa existente',
      (tester) async {
    final repository = _ChatRepository(<Conversation>[
      _conversation(1, unread: 2),
    ]);
    await _open(tester, repository);
    expect(find.byType(ConversationTile), findsOneWidget);
    expect(find.text('Pessoa 1'), findsOneWidget);
    expect(find.text('Vamos jogar 1?'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.tap(find.byKey(const Key('conversation-c1')));
    await tester.pumpAndSettle();
    expect(find.text('sala c1'), findsOneWidget);
  });

  testWidgets('ação da lista abre nova conversa sem duplicar botão',
      (tester) async {
    await _open(tester, _ChatRepository(<Conversation>[_conversation(1)]));
    expect(find.text(AppStrings.chatStartConversation), findsNothing);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('nova conversa'), findsOneWidget);
  });

  testWidgets('carregamento e erro apresentam estados completos com retry',
      (tester) async {
    final repository = _ChatRepository(<Conversation>[])
      ..firstPageGate = Completer<void>();
    await _open(tester, repository, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.fail = true;
    repository.firstPageGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.chatLoadErrorTitle), findsOneWidget);
    expect(find.text(AppStrings.chatLoadErrorHint), findsOneWidget);
    expect(find.text('sem rede'), findsNothing);
    repository.fail = false;
    await tester.tap(find.text(AppStrings.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.chatEmptyTitle), findsOneWidget);
    expect(repository.fetchCalls, 2);
  });

  testWidgets('rolagem carrega a próxima página sem perder a primeira',
      (tester) async {
    final repository = _ChatRepository(<Conversation>[
      for (var i = 0; i < 12; i++) _conversation(i),
    ]);
    final (_, container) = await _open(
      tester,
      repository,
      size: const Size(320, 480),
    );
    expect(
        container.read(paginatedConversationsProvider).valueOrNull?.length, 10);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(
        container.read(paginatedConversationsProvider).valueOrNull?.length, 12);
    expect(repository.cursors, <Object?>[null, 10]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha da próxima página preserva lista e permite repetir',
      (tester) async {
    final repository = _ChatRepository(<Conversation>[
      for (var i = 0; i < 12; i++) _conversation(i),
    ])
      ..failMore = true;
    final (_, container) = await _open(
      tester,
      repository,
      size: const Size(320, 480),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(
        container.read(paginatedConversationsProvider).valueOrNull?.length, 10);
    expect(find.text(AppStrings.chatLoadMoreError), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.failMore = false;
    await tester.tap(find.text(AppStrings.commonRetry));
    await tester.pumpAndSettle();
    expect(
        container.read(paginatedConversationsProvider).valueOrNull?.length, 12);
    expect(find.text(AppStrings.chatLoadMoreError), findsNothing);
  });
}
