import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/chat/presentation/providers/chat_providers.dart';
import 'package:mvp_compy/features/friends/data/datasources/in_memory_friendships.dart';
import 'package:mvp_compy/features/friends/domain/entities/friendship.dart';
import 'package:mvp_compy/features/friends/domain/repositories/friendships_repository.dart';
import 'package:mvp_compy/features/friends/presentation/pages/friends_page.dart';
import 'package:mvp_compy/features/friends/presentation/providers/friends_providers.dart';
import 'package:mvp_compy/features/friends/presentation/widgets/friendship_actions.dart';
import 'package:mvp_compy/features/profile/domain/entities/user_profile.dart';
import 'package:mvp_compy/features/profile/domain/repositories/profile_repository.dart';
import 'package:mvp_compy/features/profile/presentation/pages/public_profile_page.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/features/profile/presentation/widgets/friends_avatars.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/user_avatar.dart';

const a = UserSummary(id: 'a', name: 'Ana', handle: '@ana', avatarUrl: '');
const b = UserSummary(id: 'b', name: 'Bruno', handle: '@bruno', avatarUrl: '');
UserProfile profile(UserSummary user) => UserProfile(
    summary: user,
    bio: '',
    favoriteSports: const [],
    badges: const [],
    friends: const [],
    gallery: const []);

class _Profiles implements ProfileRepository {
  final users = <String, UserSummary?>{'a': a, 'b': b};
  final changes = StreamController<void>.broadcast();
  int listens = 0;
  int cancels = 0;
  @override
  Future<UserProfile?> getPublicProfile(String uid) async =>
      users[uid] == null ? null : profile(users[uid]!);
  @override
  Stream<UserSummary?> watchPublicSummary(String uid) =>
      Stream.multi((controller) {
        listens++;
        final sub =
            changes.stream.listen((_) => controller.addSync(users[uid]));
        controller.addSync(users[uid]);
        controller.onCancel = () {
          cancels++;
          return sub.cancel();
        };
      });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Relations implements FriendshipsRepository {
  final store = InMemoryFriendships();
  bool failWrite = false;
  bool failRead = false;
  Completer<void>? gate;
  int sends = 0;
  int watches = 0;
  int cancels = 0;
  @override
  Stream<List<Friendship>> watchFor(String uid) => Stream.multi((controller) {
        watches++;
        if (failRead) {
          controller.addErrorSync(StateError('offline'));
          controller.closeSync();
          return;
        }
        final sub = store.watchFor(uid).listen(controller.addSync);
        controller.onCancel = () {
          cancels++;
          return sub.cancel();
        };
      });
  @override
  Future<void> send(String uid, String peerId) async {
    sends++;
    await gate?.future;
    if (failWrite) throw StateError('offline');
    await store.send(uid, peerId);
  }

  @override
  Future<void> act(
      String uid, Friendship expected, FriendshipAction action) async {
    if (failWrite) throw StateError('offline');
    await store.act(uid, expected, action);
  }
}

ProviderContainer _client(
    String uid, _Relations relations, _Profiles profiles) {
  final container = ProviderContainer(overrides: [
    currentUserIdProvider.overrideWithValue(uid),
    currentUserSummaryProvider.overrideWith((ref) async => uid == 'a' ? a : b),
    friendshipsRepositoryProvider.overrideWithValue(relations),
    profileRepositoryProvider.overrideWithValue(profiles),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<GoRouter> open(
    WidgetTester tester, ProviderContainer container, String path,
    {double scale = 1}) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: path, routes: [
    GoRoute(
        path: AppRoutes.publicProfile,
        builder: (_, state) =>
            PublicProfilePage(uid: state.pathParameters['uid']!)),
    GoRoute(
        path: AppRoutes.friends,
        builder: (_, state) => FriendsPage(
            initialTab:
                int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0)),
    GoRoute(
        path: '/preview',
        builder: (_, __) => const Scaffold(body: FriendsSection())),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!))));
  await tester.pumpAndSettle();
  return router;
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  late _Profiles profiles;
  late _Relations relations;
  setUp(() {
    profiles = _Profiles();
    relations = _Relations();
    addTearDown(profiles.changes.close);
    addTearDown(relations.store.dispose);
  });
  testWidgets(
      'controles não aparecem para o próprio UID e aba oculta libera assinaturas',
      (tester) async {
    await relations.store.send('a', 'b');
    await relations.store.act(
        'b', relations.store.relations.values.single, FriendshipAction.accept);
    final container = _client('a', relations, profiles);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Scaffold(
                body: ValueListenableBuilder<bool>(
                    valueListenable: visible,
                    builder: (_, active, __) => TickerMode(
                        enabled: active,
                        child: const Column(children: [
                          FriendshipActions(peerId: 'a'),
                          FriendsSection()
                        ])))))));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.friendsAdd), findsNothing);
    expect(relations.watches, 1);
    expect(profiles.listens, 1);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(relations.cancels, 1);
    expect(profiles.cancels, 1);
  });
  testWidgets('lista apresenta 25 por etapa sem buscar todos os perfis',
      (tester) async {
    for (var i = 0; i < 30; i++) {
      final uid = 'peer$i';
      profiles.users[uid] = UserSummary(
          id: uid, name: 'Pessoa $i', handle: '@p$i', avatarUrl: '');
      await relations.store.send('a', uid);
      await relations.store.act(
          uid,
          relations.store.relations[Friendship.pairId('a', uid)]!,
          FriendshipAction.accept);
    }
    await open(tester, _client('a', relations, profiles), AppRoutes.friends);
    expect(find.text('Amigos (30)'), findsOneWidget);
    expect(profiles.listens, lessThan(30));
    final scrollable = find
        .descendant(
            of: find.byType(ListView).first, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text(AppStrings.friendsLoadMore), 500,
        scrollable: scrollable);
    await tap(tester, AppStrings.friendsLoadMore);
    expect(find.text(AppStrings.friendsLoadMore), findsNothing);
    expect(relations.watches, 1);
  });
  testWidgets(
      'A envia, B aceita; ambos veem amizade e remoção só após confirmar',
      (tester) async {
    final ca = _client('a', relations, profiles);
    final cb = _client('b', relations, profiles);
    final sa = ca.listen(friendshipsProvider, (_, __) {});
    final sb = cb.listen(friendshipsProvider, (_, __) {});
    await open(tester, ca, AppRoutes.publicProfileFor('b'));
    expect(find.text(AppStrings.profileMessage), findsOneWidget);
    await tap(tester, AppStrings.friendsAdd);
    expect(find.text(AppStrings.friendsSentState), findsOneWidget);
    expect(relations.store.relations.values.single.status,
        FriendshipStatus.pending);
    await open(tester, cb, '${AppRoutes.friends}?tab=1');
    expect(find.text('@ana'), findsOneWidget);
    expect(find.text(AppStrings.friendsRespond), findsOneWidget);
    await tap(tester, AppStrings.friendsAccept);
    expect(find.text('@ana'), findsNothing);
    expect(ca.read(friendshipsProvider).valueOrNull!.single.status,
        FriendshipStatus.accepted);
    expect(cb.read(friendshipsProvider).valueOrNull!.single.status,
        FriendshipStatus.accepted);
    await tap(tester, 'Amigos (1)');
    expect(find.text('@ana'), findsOneWidget);
    await tap(tester, AppStrings.friendsRemove);
    await tap(tester, AppStrings.commonCancel);
    expect(relations.store.relations, hasLength(1));
    await tap(tester, AppStrings.friendsRemove);
    await tap(tester, AppStrings.friendsRemove);
    expect(relations.store.relations, isEmpty);
    expect(ca.read(friendshipsProvider).valueOrNull, isEmpty);
    expect(relations.watches, 2);
    sa.close();
    sb.close();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets('recusa recebida e cancelamento enviado atualizam listas',
      (tester) async {
    final cb = _client('b', relations, profiles);
    await relations.store.send('a', 'b');
    await open(tester, cb, '${AppRoutes.friends}?tab=1');
    await tap(tester, AppStrings.friendsDecline);
    expect(relations.store.relations, isEmpty);
    await relations.store.send('b', 'a');
    await tester.pumpAndSettle();
    await tap(tester, 'Enviadas (1)');
    expect(find.text(AppStrings.friendsSentState), findsOneWidget);
    await tap(tester, AppStrings.friendsCancel);
    expect(relations.store.relations, isEmpty);
  });
  testWidgets('solicitação recebida no perfil oferece aceitar e recusar',
      (tester) async {
    await relations.store.send('b', 'a');
    await open(tester, _client('a', relations, profiles),
        AppRoutes.publicProfileFor('b'));
    expect(find.text(AppStrings.friendsRespond), findsOneWidget);
    expect(find.text(AppStrings.friendsAccept), findsOneWidget);
    await tap(tester, AppStrings.friendsDecline);
    expect(find.text(AppStrings.friendsAdd), findsOneWidget);
    expect(relations.store.relations, isEmpty);
  });
  testWidgets('falha mantém estado e permite repetir, sem ações duplicadas',
      (tester) async {
    relations.failWrite = true;
    final container = _client('a', relations, profiles);
    await open(tester, container, AppRoutes.publicProfileFor('b'));
    await tap(tester, AppStrings.friendsAdd);
    expect(find.text(AppStrings.friendsOperationError), findsOneWidget);
    expect(find.text(AppStrings.friendsConfirmed), findsNothing);
    expect(relations.store.relations, isEmpty);
    relations.failWrite = false;
    relations.gate = Completer<void>();
    await tester.tap(find.text(AppStrings.friendsAdd));
    await tester.pump();
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, AppStrings.friendsAdd));
    expect(button.onPressed, isNull);
    expect(relations.sends, 2);
    relations.gate!.complete();
    await tester.pumpAndSettle();
    expect(relations.store.relations, hasLength(1));
  });
  testWidgets('lista usa perfil atual e permanece estável quando perfil some',
      (tester) async {
    await relations.store.send('a', 'b');
    await relations.store.act(
        'b', relations.store.relations.values.single, FriendshipAction.accept);
    final container = _client('a', relations, profiles);
    final router = await open(tester, container, AppRoutes.friends, scale: 1.5);
    profiles.users['b'] = const UserSummary(
        id: 'b',
        name:
            'Nome muito comprido de uma pessoa que pratica diferentes esportes em Taquara',
        handle: '@bruno.atualizado',
        avatarUrl: 'https://example.test/new.jpg');
    profiles.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('@bruno.atualizado'), findsOneWidget);
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).user?.avatarUrl,
        'https://example.test/new.jpg');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('friend-profile-b')));
    await tester.pumpAndSettle();
    expect(tester.widget<PublicProfilePage>(find.byType(PublicProfilePage)).uid,
        'b');
    router.go(AppRoutes.friends);
    await tester.pumpAndSettle();
    profiles.users['b'] = null;
    profiles.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.friendsMissingProfile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, AppStrings.friendsRemove);
    await tap(tester, AppStrings.friendsRemove);
    expect(relations.store.relations, isEmpty);
  });
  testWidgets(
      'vazio, erro e repetição da lista; perfil ausente não oferece amizade',
      (tester) async {
    relations.failRead = true;
    final container = _client('a', relations, profiles);
    final router = await open(tester, container, AppRoutes.friends);
    expect(find.text(AppStrings.friendsLoadError), findsOneWidget);
    relations.failRead = false;
    await tap(tester, AppStrings.commonRetry);
    expect(find.text(AppStrings.friendsEmptyList), findsWidgets);
    router.go(AppRoutes.publicProfileFor('missing'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.profilePublicNotFound), findsOneWidget);
    expect(find.byType(FriendshipActions), findsNothing);
  });
  testWidgets('prévia exibe contagem e pendências, sem amigos fictícios',
      (tester) async {
    final container = _client('a', relations, profiles);
    await open(tester, container, '/preview');
    expect(find.text(AppStrings.friendsEmpty), findsOneWidget);
    expect(find.byType(UserAvatar), findsNothing);
    await relations.store.send('b', 'a');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.friendsRequestsCount(1)), findsOneWidget);
    await relations.store.act(
        'a', relations.store.relations.values.single, FriendshipAction.accept);
    await tester.pumpAndSettle();
    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.text('Amigos (1)'), findsOneWidget);
    expect(find.text(AppStrings.friendsRequestsCount(1)), findsNothing);
    await tap(tester, AppStrings.friendsSeeAll);
    expect(find.byType(FriendsPage), findsOneWidget);
  });
}
