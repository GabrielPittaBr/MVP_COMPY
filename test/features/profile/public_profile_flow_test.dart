import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/chat/domain/entities/conversation.dart';
import 'package:mvp_compy/features/chat/domain/entities/message.dart';
import 'package:mvp_compy/features/chat/domain/repositories/chat_repository.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/pages/event_detail_page.dart';
import 'package:mvp_compy/features/profile/presentation/pages/profile_page.dart';
import 'package:mvp_compy/features/profile/presentation/pages/public_profile_page.dart';
import 'package:mvp_compy/features/chat/presentation/pages/chat_room_page.dart';
import 'package:mvp_compy/features/chat/presentation/pages/new_conversation_page.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:mvp_compy/features/profile/domain/entities/user_profile.dart';
import 'package:mvp_compy/features/profile/domain/repositories/profile_repository.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

const me =
    UserSummary(id: 'me', name: 'Meu Nome', handle: '@me', avatarUrl: '');
const peer = UserSummary(
  id: 'other',
  name: 'Ana Pereira',
  handle: '@ana',
  avatarUrl: '',
);
const participant = UserSummary(
  id: 'third',
  name: 'Bruno Silva',
  handle: '@bruno',
  avatarUrl: '',
);

UserProfile profile(UserSummary summary,
        {String bio = '', List<Sport> sports = const []}) =>
    UserProfile(
      summary: summary,
      bio: bio,
      favoriteSports: sports,
      badges: const [],
      friends: const [],
      gallery: const [],
    );

class _Profiles implements ProfileRepository {
  bool failRead = false;
  Completer<UserProfile?>? pendingRead;
  final data = <String, UserProfile>{
    'other': profile(peer, bio: 'Gosto de vôlei.', sports: const [Sport.volei]),
    'third': profile(participant),
  };

  @override
  Future<UserProfile?> getPublicProfile(String uid) async {
    if (failRead) throw StateError('Sem permissão');
    final pending = pendingRead;
    if (pending != null) return pending.future;
    return data[uid];
  }

  @override
  Stream<UserSummary?> watchPublicSummary(String uid) =>
      Stream<UserSummary?>.value(data[uid]?.summary);

  @override
  Future<UserProfile> getCurrentProfile(String uid) async => profile(me);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat implements ChatRepository {
  int opens = 0;
  String? lastPeer;
  bool failOpen = false;

  Conversation get conversation => Conversation(
        id: Conversation.idBetween(me.id, peer.id),
        peer: peer,
        lastMessage: 'Mensagem preservada',
        unreadCount: 0,
        lastMessageAt: DateTime(2026, 10, 22),
      );

  @override
  Future<String> openConversationWith({
    required UserSummary me,
    required UserSummary peer,
  }) async {
    opens++;
    if (failOpen) throw StateError('Indisponível');
    lastPeer = peer.id;
    return Conversation.idBetween(me.id, peer.id);
  }

  @override
  Future<PagedResult<Conversation>> fetchConversationsPage(String userId,
          {Object? cursor, int pageSize = 10}) async =>
      PagedResult(items: [conversation], hasMore: false);

  @override
  Stream<List<Conversation>> watchConversationsFirstPage(String userId,
          {int limit = 10}) =>
      Stream.value([conversation]);

  @override
  Future<Conversation?> fetchConversation(
          String conversationId, String userId) async =>
      conversationId == conversation.id ? conversation : null;

  @override
  Stream<List<Message>> watchMessages(String conversationId) => Stream.value([
        Message(
          id: 'm1',
          conversationId: conversationId,
          senderId: peer.id,
          text: 'Mensagem preservada',
          sentAt: DateTime(2026, 10, 22),
        ),
      ]);

  @override
  Future<void> markAsRead(String conversationId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _agora = DateTime(2026, 10, 22, 12);

class _Events implements EventsRepository {
  final event = Event(
    id: 'event',
    title: 'Vôlei da turma',
    sport: Sport.volei,
    location: 'Taquara',
    coordinates: const LatLng(-29.65, -50.78),
    dateTime: DateTime(2026, 11, 1),
    durationMinutes: 60,
    skillLevel: SkillLevel.iniciante,
    totalSpots: 20,
    remainingSpots: 8,
    bannerUrl: '',
    creator: peer,
    participants: const [
      me,
      peer,
      UserSummary(id: 'p1', name: 'Pessoa 1', handle: '@p1', avatarUrl: ''),
      UserSummary(id: 'p2', name: 'Pessoa 2', handle: '@p2', avatarUrl: ''),
      UserSummary(id: 'p3', name: 'Pessoa 3', handle: '@p3', avatarUrl: ''),
      UserSummary(id: 'p4', name: 'Pessoa 4', handle: '@p4', avatarUrl: ''),
      UserSummary(id: 'p5', name: 'Pessoa 5', handle: '@p5', avatarUrl: ''),
      UserSummary(id: 'p6', name: 'Pessoa 6', handle: '@p6', avatarUrl: ''),
      participant,
    ],
  );

  @override
  Future<Event?> getById(String id) async => id == event.id ? event : null;

  // O detalhe acompanha o evento em tempo real desde a tarefa 14.
  @override
  Stream<Event?> watchById(String id) =>
      Stream.value(id == event.id ? event : null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('consulta por UID não troca perfil inexistente pelo próprio mock',
      () async {
    final repository = ProfileRepositoryImpl(null);
    expect((await repository.getPublicProfile('u_douglas'))?.summary.id,
        'u_douglas');
    expect(await repository.getPublicProfile('sumiu'), isNull);
    expect(await repository.getPublicProfile(''), isNull);
    expect(await repository.getPublicProfile('a/b'), isNull);
    expect(await repository.getPublicProfile('..'), isNull);
    expect((await repository.watchPublicSummary('u_douglas').first)?.id,
        'u_douglas');
    expect(await repository.watchPublicSummary('sumiu').first, isNull);
    expect(await repository.watchPublicSummary('a/b').first, isNull);
  });

  Future<(GoRouter, ProviderContainer)> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profiles = _Profiles();
    final chat = _Chat();
    final events = _Events();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((_) => Stream.value(const AuthUser(
            uid: 'me',
            email: 'private@example.com',
            displayName: 'Meu Nome',
            hasUsername: true,
            hasFavoriteSports: true,
          ))),
      currentUserIdProvider.overrideWith((_) => 'me'),
      currentProfileProvider.overrideWith((_) async => profile(me)),
      profileRepositoryProvider.overrideWithValue(profiles),
      chatRepositoryProvider.overrideWithValue(chat),
      eventsRepositoryProvider.overrideWithValue(events),
      userSearchProvider.overrideWith((_, __) async => [peer]),
      // O detalhe do evento lê o relógio da tarefa 14; fixo, sem o timer
      // periódico que derrubaria o teste. O evento do teste ainda não começou.
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.publicProfileFor('other'),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) => shell.goBranch(index),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.event), label: 'Eventos'),
                NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
                NavigationDestination(
                    icon: Icon(Icons.person), label: 'Perfil'),
              ],
            ),
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.events,
                builder: (_, __) => const Scaffold(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        EventDetailPage(eventId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (_, __) => const Scaffold(),
                routes: [
                  GoRoute(
                    path: 'nova',
                    builder: (_, __) => const NewConversationPage(),
                  ),
                  GoRoute(
                    path: ':conversationId',
                    builder: (_, state) => ChatRoomPage(
                      conversationId: state.pathParameters['conversationId']!,
                    ),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'usuarios/:uid',
                    builder: (_, state) =>
                        PublicProfilePage(uid: state.pathParameters['uid']!),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return (router, container);
  }

  testWidgets(
      'rota por UID mostra apenas dados públicos corretos e estados vazios',
      (tester) async {
    final (router, _) = await launch(tester);
    router.go(AppRoutes.publicProfileFor('other'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Pereira'), findsOneWidget);
    expect(find.text('@ana'), findsOneWidget);
    expect(find.text('Gosto de vôlei.'), findsOneWidget);
    expect(find.text('Vôlei'), findsOneWidget);
    expect(find.text('private@example.com'), findsNothing);
    expect(find.text(AppStrings.profileMessage), findsOneWidget);
    router.go(AppRoutes.publicProfileFor('missing'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.profilePublicNotFound), findsOneWidget);
    expect(find.text('Ana Pereira'), findsNothing);
    router.go(AppRoutes.publicProfileFor('third'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.profileNoFavoriteSports), findsOneWidget);
    expect(find.text('Gosto de vôlei.'), findsNothing);
  });

  testWidgets('UID próprio abre perfil próprio sem mensagem', (tester) async {
    final (router, _) = await launch(tester);
    router.go(AppRoutes.publicProfileFor('me'));
    await tester.pumpAndSettle();
    expect(find.text('Meu Nome'), findsOneWidget);
    expect(find.text(AppStrings.profileEdit), findsOneWidget);
    expect(find.text(AppStrings.profileMessage), findsNothing);
  });

  testWidgets('organizador e participante abrem perfis distintos',
      (tester) async {
    final (router, _) = await launch(tester);
    router.go('/events/event');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('event-creator-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-creator-profile')));
    await tester.pumpAndSettle();
    expect(find.text('@ana'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('participants-see-all')));
    await tester.tap(find.byKey(const Key('participants-see-all')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('participant-row-third')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('participants-full-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('participant-row-third')));
    await tester.pumpAndSettle();
    expect(find.text('@bruno'), findsOneWidget);
  });

  testWidgets('evento → organizador → mensagem → volta ao evento',
      (tester) async {
    final (router, _) = await launch(tester);
    router.go('/events/event');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('event-creator-profile')));
    await tester.tap(find.byKey(const Key('event-creator-profile')));
    await tester.pumpAndSettle();
    expect(find.text('@ana'), findsOneWidget);
    await tester.tap(find.text(AppStrings.profileMessage));
    await tester.pumpAndSettle();
    expect(find.text('Mensagem preservada'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('@ana'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailPage), findsOneWidget);
  });

  testWidgets('chat abre perfil e retorna à mesma conversa', (tester) async {
    final (router, _) = await launch(tester);
    router.go('/chat/${Conversation.idBetween(me.id, peer.id)}');
    await tester.pumpAndSettle();
    expect(find.text('Mensagem preservada'), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    await tester.tap(find.text('Ana Pereira').first);
    await tester.pumpAndSettle();
    expect(find.text('@ana'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Mensagem preservada'), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
  });

  testWidgets('perfil inicia conversa pelo fluxo existente', (tester) async {
    final (router, container) = await launch(tester);
    router.go(AppRoutes.publicProfileFor('other'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.profileMessage));
    await tester.pumpAndSettle();
    final chat = container.read(chatRepositoryProvider) as _Chat;
    expect(chat.opens, 1);
    expect(chat.lastPeer, 'other');
    expect(find.text('Mensagem preservada'), findsOneWidget);
  });

  testWidgets('erro de leitura permite tentar novamente', (tester) async {
    final (router, container) = await launch(tester);
    final profiles = container.read(profileRepositoryProvider) as _Profiles;
    profiles.failRead = true;
    router.go(AppRoutes.publicProfileFor('third'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.profilePublicError), findsOneWidget);
    profiles.failRead = false;
    await tester.tap(find.text(AppStrings.authRetry));
    await tester.pumpAndSettle();
    expect(find.text('Bruno Silva'), findsOneWidget);
  });

  testWidgets('carregamento não mostra perfil anterior', (tester) async {
    final (router, container) = await launch(tester);
    final profiles = container.read(profileRepositoryProvider) as _Profiles;
    profiles.pendingRead = Completer<UserProfile?>();
    router.go(AppRoutes.publicProfileFor('third'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ana Pereira'), findsNothing);
    profiles.pendingRead!.complete(profile(participant));
    await tester.pumpAndSettle();
    expect(find.text('Bruno Silva'), findsOneWidget);
  });

  testWidgets('falha ao abrir conversa libera o botão', (tester) async {
    final (_, container) = await launch(tester);
    final chat = container.read(chatRepositoryProvider) as _Chat;
    chat.failOpen = true;
    await tester.tap(find.text(AppStrings.profileMessage));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.chatOpenConversationError), findsOneWidget);
    chat.failOpen = false;
    await tester.tap(find.text(AppStrings.profileMessage));
    await tester.pumpAndSettle();
    expect(chat.opens, 2);
    expect(find.text('Mensagem preservada'), findsOneWidget);
  });

  testWidgets('busca abre perfil pela linha e mantém atalho de conversa',
      (tester) async {
    final (router, container) = await launch(tester);
    router.go(AppRoutes.chatNew);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'an');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Pereira'));
    await tester.pumpAndSettle();
    expect(find.text('Gosto de vôlei.'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.profileMessage));
    await tester.pumpAndSettle();
    expect((container.read(chatRepositoryProvider) as _Chat).opens, 1);
  });
}
