import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/constants/app_assets.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/chat/data/mappers/conversation_mapper.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';
import 'package:mvp_compy/features/chat/domain/entities/message.dart';
import 'package:mvp_compy/features/chat/domain/repositories/chat_repository.dart';
import 'package:mvp_compy/features/chat/presentation/pages/chat_room_page.dart';
import 'package:mvp_compy/features/chat/presentation/pages/conversations_page.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:mvp_compy/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/user_avatar.dart';

const _old = UserSummary(
  id: 'B',
  name: 'Bruno',
  handle: '@bruno',
  avatarUrl: 'https://example.com/old.jpg',
);

// Simula documentos persistidos e snapshots do SDK. Os dois clientes usam
// os repositórios de perfil reais e containers Riverpod independentes.
// ignore: subtype_of_sealed_class, must_be_immutable
class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileRemoteDataSource {
  Map<String, dynamic>? data = _old.toMap();
  int listens = 0;
  int watches = 0;
  int cancels = 0;
  int fetches = 0;
  late final source =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
    onListen: () {
      listens++;
      scheduleMicrotask(emit);
    },
    onCancel: () => cancels++,
  );

  void emit() => source.add(_Snapshot('B', data == null ? null : {...data!}));

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchById(String userId) {
    expectSync(userId, 'B');
    watches++;
    return source.stream;
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(
      String userId) async {
    expectSync(userId, 'B');
    fetches++;
    return _Snapshot('B', data == null ? null : {...data!});
  }

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) async =>
      'https://example.com/avatar_${jpeg.first}.jpg';

  @override
  Future<void> updateAvatarUrl(String userId, String avatarUrl) async {
    data = {...data!, 'avatarUrl': avatarUrl};
    emit();
  }

  @override
  Future<void> updatePublicDetails(String uid, String name, String bio) async {
    data = {...data!, 'name': name, 'bio': bio};
    emit();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat implements ChatRepository {
  _Chat({bool legacy = false})
      : conversation = ConversationMapper.fromMap(
            'A_B',
            {
              'members': ['A', 'B'],
              if (!legacy) 'memberSummaries': {'B': _old.toMap()},
              'lastMessage': 'Histórico preservado',
              'lastMessageAt': Timestamp.fromDate(DateTime(2026, 10, 29)),
              'unreadCounts': {'A': 2},
            },
            'A');
  final Conversation conversation;
  int fetches = 0;
  @override
  Future<PagedResult<Conversation>> fetchConversationsPage(String userId,
      {Object? cursor, int pageSize = 10}) async {
    fetches++;
    return PagedResult(items: [conversation], hasMore: false);
  }

  @override
  Stream<List<Conversation>> watchConversationsFirstPage(String userId,
          {int limit = 10}) =>
      Stream.value([conversation]);
  @override
  Future<Conversation?> fetchConversation(
          String conversationId, String userId) async =>
      conversation;
  @override
  Future<void> markAsRead(String conversationId) async {}
  @override
  Stream<List<Message>> watchMessages(String conversationId) => Stream.value([
        for (var i = 0; i < 3; i++)
          Message(
              id: 'm$i',
              conversationId: conversationId,
              senderId: 'B',
              text: 'Mensagem $i preservada',
              sentAt: DateTime(2026, 10, 29, 12, i)),
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _client(_Profiles profiles, _Chat chat) => ProviderContainer(
      overrides: [
        profileRepositoryProvider
            .overrideWithValue(ProfileRepositoryImpl(profiles)),
        chatRepositoryProvider.overrideWithValue(chat),
        currentUserIdProvider.overrideWithValue('A'),
      ],
    );

Future<GoRouter> _open(WidgetTester tester, ProviderContainer client) async {
  tester.view.physicalSize = const Size(1100, 800);
  tester.view.devicePixelRatio = 1;
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => const Row(children: [
              Expanded(child: ConversationsPage()),
              Expanded(child: ChatRoomPage(conversationId: 'A_B')),
            ])),
    GoRoute(
        path: AppRoutes.publicProfile,
        builder: (_, state) =>
            Scaffold(body: Text('perfil ${state.pathParameters['uid']}'))),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: client,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

void _expectIdentity(WidgetTester tester, String name, String avatar) {
  // Uma linha, cabeçalho e três mensagens: todos recebem a mesma identidade.
  expect(find.text(name), findsNWidgets(2));
  final users = tester.widgetList<UserAvatar>(find.byType(UserAvatar)).toList();
  expect(users, hasLength(5));
  expect(
      users.every((widget) =>
          widget.user?.id == 'B' &&
          widget.user?.name == name &&
          widget.user?.avatarUrl == avatar),
      isTrue);
  final images =
      tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
  if (AppAssets.isPlaceholderAvatar(avatar)) {
    expect(images, isEmpty);
    expect(find.byIcon(Icons.person), findsNWidgets(5));
  } else {
    expect(images, hasLength(5));
    expect(images.every((image) => image.imageUrl == avatar), isTrue);
  }
  for (var i = 0; i < 3; i++) {
    expect(find.text('Mensagem $i preservada'), findsOneWidget);
  }
}

void main() {
  test('fallback, remoção explícita e assinatura compartilhada por UID',
      () async {
    final profiles = _Profiles();
    final client = _client(profiles, _Chat());
    final first = client.listen(conversationPeerProvider(_old), (_, __) {});
    expect(first.read(), _old); // Antes da primeira emissão.
    const otherSnapshot =
        UserSummary(id: 'B', name: 'Legado', handle: '', avatarUrl: '');
    final second =
        client.listen(conversationPeerProvider(otherSnapshot), (_, __) {});
    await Future<void>.delayed(Duration.zero);
    await client.pump();
    expect(profiles.listens, 1);
    expect(profiles.watches, 1);
    profiles.data = {..._old.toMap(), 'name': 'Nome atual', 'avatarUrl': ''};
    profiles.emit();
    await Future<void>.delayed(Duration.zero);
    await client.pump();
    expect(first.read().avatarUrl, isEmpty);
    expect(second.read().name, 'Nome atual');
    profiles.source.addError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    await client.pump();
    expect(first.read().name, 'Nome atual');
    expect(first.read().avatarUrl, isEmpty);
    profiles.data = null;
    profiles.emit();
    await Future<void>.delayed(Duration.zero);
    await client.pump();
    expect(first.read(), _old);
    expect(second.read(), otherSnapshot);
    client.listen(
        conversationPeerProvider(ConversationMapper.unknownPeer), (_, __) {});
    expect(profiles.listens, 1);
    expect(profiles.watches, 1);
    first.close();
    second.close();
    await client.pump();
    expect(profiles.cancels, 1);
    client.dispose();
    await profiles.source.close();
  });

  testWidgets('A acompanha alterações de B e reabre a conversa intacta',
      (tester) async {
    addTearDown(tester.view.reset);
    final profiles = _Profiles();
    final chat = _Chat();
    final b = ProviderContainer(overrides: [
      profileRepositoryProvider
          .overrideWithValue(ProfileRepositoryImpl(profiles)),
      authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
            uid: 'B',
            email: '',
            displayName: 'Bruno',
            hasUsername: true,
            hasFavoriteSports: true,
          ))),
    ]);
    addTearDown(b.dispose);
    await b.read(authStateProvider.future);
    final public = b.listen(publicProfileProvider('B'), (_, __) {});
    expect((await b.read(currentProfileProvider.future)).summary, _old);
    await b.read(publicProfileProvider('B').future);
    await b.read(avatarControllerProvider.future);
    var a = _client(profiles, chat);
    var router = await _open(tester, a);
    _expectIdentity(tester, 'Bruno', _old.avatarUrl);

    for (final version in [1, 2, null, 3]) {
      final saved = await b
          .read(avatarControllerProvider.notifier)
          .save(_old, version == null ? null : Uint8List.fromList([version]));
      expect(saved, isTrue);
      await tester.pumpAndSettle();
      final url = version == null
          ? AppAssets.avatar('Bruno')
          : 'https://example.com/avatar_$version.jpg';
      _expectIdentity(tester, 'Bruno', url);
      expect(
          (await b.read(currentProfileProvider.future)).summary.avatarUrl, url);
      expect(
          (await b.read(publicProfileProvider('B').future))!.summary.avatarUrl,
          url);
    }
    await b.read(profileRepositoryProvider).updateDetails('B',
        name: 'Bruno Atualizado', bio: '', nameChanged: false);
    await tester.pumpAndSettle();
    _expectIdentity(
        tester, 'Bruno Atualizado', 'https://example.com/avatar_3.jpg');
    expect(profiles.listens, 1);
    expect(profiles.watches, 1);
    expect(chat.fetches, 1); // Nenhum refresh da lista por troca de foto/nome.
    expect(chat.conversation.peer, _old); // Snapshot histórico intacto.

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    a.dispose();
    await tester.pump();
    a = _client(profiles, chat);
    router = await _open(tester, a);
    _expectIdentity(
        tester, 'Bruno Atualizado', 'https://example.com/avatar_3.jpg');
    await tester.tap(find.text('Bruno Atualizado').last);
    await tester.pumpAndSettle();
    expect(find.text('perfil B'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    a.dispose();
    public.close();
    await tester.pump(const Duration(milliseconds: 1));
    await profiles.source.close();
  });

  testWidgets(
      'conversa legada recupera perfil; ausência e erro preservam histórico',
      (tester) async {
    addTearDown(tester.view.reset);
    final profiles = _Profiles();
    final chat = _Chat(legacy: true);
    final client = _client(profiles, chat);
    final router = await _open(tester, client);
    _expectIdentity(tester, 'Bruno', _old.avatarUrl);
    profiles.data = null;
    profiles.emit();
    await tester.pumpAndSettle();
    _expectIdentity(tester, ConversationMapper.unknownPeer.name, '');
    profiles.source.addError(StateError('perfil indisponível'));
    await tester.pumpAndSettle();
    _expectIdentity(tester, ConversationMapper.unknownPeer.name, '');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    client.dispose();
    await profiles.source.close();
  });
}
