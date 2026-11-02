import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/events/presentation/widgets/participants_avatars.dart';
import 'package:mvp_compy/features/profile/domain/repositories/profile_repository.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/user_avatar.dart';

const organizer =
    UserSummary(id: 'owner', name: 'Ana', handle: '@ana', avatarUrl: '');
const guest =
    UserSummary(id: 'guest', name: 'Bruno', handle: '@bruno', avatarUrl: '');
const third =
    UserSummary(id: 'third', name: 'Carla', handle: '@carla', avatarUrl: '');

class _Profiles implements ProfileRepository {
  late GoRouter router;
  final initial = <String, UserSummary>{};
  final streams = <String, StreamController<UserSummary?>>{};
  final listens = <String, int>{};
  final cancels = <String, int>{};

  @override
  Stream<UserSummary?> watchPublicSummary(String uid) {
    final controller = streams.putIfAbsent(
      uid,
      () {
        late final StreamController<UserSummary?> source;
        source = StreamController<UserSummary?>.broadcast(
          onListen: () {
            listens.update(uid, (value) => value + 1, ifAbsent: () => 1);
            scheduleMicrotask(() {
              if (!source.isClosed) source.add(initial[uid]);
            });
          },
          onCancel: () =>
              cancels.update(uid, (value) => value + 1, ifAbsent: () => 1),
        );
        return source;
      },
    );
    return controller.stream;
  }

  void emit(String uid, UserSummary? user) => streams[uid]!.add(user);

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Profiles> _open(
  WidgetTester tester, {
  List<UserSummary> participants = const <UserSummary>[organizer, guest, third],
  UserSummary owner = organizer,
  String? meId,
  ValueChanged<UserSummary>? onMessage,
  Size size = const Size(390, 760),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final profiles = _Profiles();
  profiles.initial.addEntries(<UserSummary>[owner, ...participants]
      .map((person) => MapEntry(person.id, person)));
  addTearDown(profiles.close);
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: ParticipantsAvatars(
              participants: participants,
              organizer: owner,
              meId: meId,
              onMessage: onMessage,
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.publicProfile,
        builder: (_, state) => Scaffold(
          body: Text('perfil ${state.pathParameters['uid']}'),
        ),
      ),
      GoRoute(
        path: '/other',
        builder: (_, __) => const Scaffold(body: Text('outra tela')),
      ),
    ],
  );
  profiles.router = router;
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      profileRepositoryProvider.overrideWithValue(profiles)
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return profiles;
}

Future<void> showAll(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('participants-see-all')));
  await tester.pumpAndSettle();
}

void main() {
  test('provider cancela stream quando perde o último listener', () async {
    final profiles = _Profiles();
    profiles.initial['owner'] = organizer;
    final container = ProviderContainer(overrides: <Override>[
      profileRepositoryProvider.overrideWithValue(profiles),
    ]);
    final subscription = container.listen(
        publicUserSummaryProvider('owner'), (_, __) {},
        fireImmediately: true);
    await container.pump();
    expect(profiles.listens['owner'], 1);
    subscription.close();
    await container.pump();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(profiles.cancels['owner'], 1);
    await profiles.close();
  });

  testWidgets('um participante: resumo, organizador e fallback sem foto',
      (tester) async {
    final profiles = await _open(tester, participants: const [organizer]);
    expect(find.text(AppStrings.eventParticipants), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(const Key('participant-preview-owner')), findsOneWidget);
    expect(profiles.listens, <String, int>{'owner': 1});
    await showAll(tester);
    expect(find.byKey(const Key('participant-row-owner')), findsOneWidget);
    expect(find.text(AppStrings.eventLiveOrganizer), findsNWidgets(2));
    expect(find.byIcon(Icons.person), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista completa mostra vários e navega pela linha inteira',
      (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('participant-preview-third')), findsOneWidget);
    await showAll(tester);
    expect(find.byKey(const Key('participant-row-owner')), findsOneWidget);
    expect(find.byKey(const Key('participant-row-guest')), findsOneWidget);
    expect(find.byKey(const Key('participant-row-third')), findsOneWidget);
    expect(find.text('@bruno'), findsOneWidget);
    await tester.tap(find.byKey(const Key('participant-row-guest')));
    await tester.pumpAndSettle();
    expect(find.text('perfil guest'), findsOneWidget);
    expect(find.byKey(const Key('participants-full-list')), findsNothing);
  });

  testWidgets('avatar e nome mudam enquanto a lista está aberta',
      (tester) async {
    final profiles = await _open(tester);
    await showAll(tester);
    profiles.emit(
      'guest',
      const UserSummary(
        id: 'guest',
        name: 'Bruno Atualizado',
        handle: '@bruno',
        avatarUrl: 'https://example.com/nova-foto.jpg',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Bruno Atualizado'), findsOneWidget);
    final row = find.byKey(const Key('participant-row-guest'));
    final avatar = tester.widget<UserAvatar>(
      find.descendant(of: row, matching: find.byType(UserAvatar)),
    );
    expect(avatar.user?.avatarUrl, 'https://example.com/nova-foto.jpg');
  });

  testWidgets('perfil removido ou com falha preserva a lista e usa fallback',
      (tester) async {
    final profiles = await _open(tester);
    await showAll(tester);
    profiles.emit('guest', null);
    await tester.pump();
    final row = find.byKey(const Key('participant-row-guest'));
    expect(
        find.descendant(of: row, matching: find.text('Bruno')), findsOneWidget);
    expect(
      tester
          .widget<UserAvatar>(
              find.descendant(of: row, matching: find.byType(UserAvatar)))
          .user
          ?.avatarUrl,
      '',
    );
    profiles.streams['third']!.addError(StateError('sem conexão'));
    await tester.pump();
    expect(find.byKey(const Key('participant-row-third')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('listeners são compartilhados e liberados ao fechar/sair',
      (tester) async {
    final profiles = await _open(tester);
    expect(profiles.listens, <String, int>{'owner': 1, 'guest': 1, 'third': 1});
    await showAll(tester);
    expect(profiles.listens, <String, int>{'owner': 1, 'guest': 1, 'third': 1});
    await tester.tap(find.byTooltip(AppStrings.eventCloseParticipants));
    await tester.pumpAndSettle();
    expect(profiles.cancels, isEmpty);
    profiles.router.go('/other');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('participants-preview')), findsNothing);
    expect(
      find.byKey(const Key('participants-preview'), skipOffstage: false),
      findsNothing,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    expect(profiles.cancels, <String, int>{'owner': 1, 'guest': 1, 'third': 1});
  });

  testWidgets('vários participantes assinam só os visíveis na prévia',
      (tester) async {
    final many = <UserSummary>[
      organizer,
      for (var i = 0; i < 40; i++)
        UserSummary(
            id: 'u$i', name: 'Pessoa $i', handle: '@p$i', avatarUrl: ''),
    ];
    final profiles = await _open(tester, participants: many);
    expect(profiles.listens.keys, containsAll(<String>['owner', 'u0', 'u1']));
    expect(profiles.listens.length, 3);
    await showAll(tester);
    expect(profiles.listens.length, lessThan(many.length));
    final sheetOnly = profiles.listens.keys
        .toSet()
        .difference(<String>{'owner', 'u0', 'u1'});
    expect(sheetOnly, isNotEmpty);
    await tester.tap(find.byTooltip(AppStrings.eventCloseParticipants));
    await tester.pumpAndSettle();
    expect(profiles.cancels.keys, containsAll(sheetOnly));
    expect(profiles.cancels.keys, isNot(contains('owner')));
  });

  testWidgets('nome longo e mensagens não causam overflow em tela pequena',
      (tester) async {
    const longName = UserSummary(
      id: 'long',
      name: 'Nome imensamente comprido para uma tela de celular pequena',
      handle: '@identificador_tambem_muito_comprido',
      avatarUrl: '',
    );
    UserSummary? messaged;
    await _open(
      tester,
      size: const Size(280, 600),
      participants: <UserSummary>[organizer, longName],
      meId: 'owner',
      onMessage: (person) => messaged = person,
    );
    await showAll(tester);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip(AppStrings.eventLiveMessage(longName.name)),
        findsOneWidget);
    expect(find.byTooltip(AppStrings.eventLiveMessage(organizer.name)),
        findsNothing);
    await tester
        .tap(find.byTooltip(AppStrings.eventLiveMessage(longName.name)));
    await tester.pumpAndSettle();
    expect(messaged?.id, 'long');
    expect(tester.takeException(), isNull);
  });
}
