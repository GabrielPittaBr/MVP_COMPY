import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/notifications/domain/entities/app_notification.dart';
import 'package:mvp_compy/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mvp_compy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:mvp_compy/features/notifications/presentation/widgets/auto_end_notice.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

const _dono = UserSummary(
  id: 'u_dono',
  name: 'Ana Souza',
  handle: '@anasouza',
  avatarUrl: '',
);
const _participante = UserSummary(
  id: 'u_bruno',
  name: 'Bruno Lima',
  handle: '@brunolima',
  avatarUrl: '',
);

AppNotification _encerrado(
  String eventId, {
  bool automatico = true,
  bool lida = false,
}) =>
    AppNotification(
      id: 'eventEnded_$eventId',
      type: AppNotificationType.eventEnded,
      eventId: eventId,
      eventTitle: 'Vôlei dos Devs',
      sport: 'volei',
      creatorId: 'u_dono',
      endedAutomatically: automatico,
      createdAt: DateTime(2026, 10, 21, 20),
      readAt: lida ? DateTime(2026, 10, 21, 20) : null,
    );

class _Notificacoes implements NotificationsRepository {
  final StreamController<List<AppNotification>> emissoes =
      StreamController<List<AppNotification>>();
  final List<String> lidas = <String>[];

  @override
  Stream<List<AppNotification>> watch(String uid) => emissoes.stream;

  @override
  Future<void> markRead(String uid, String notificationId) async =>
      lidas.add(notificationId);

  @override
  Future<void> markAllRead(String uid, Iterable<String> ids) async {}
}

Future<_Notificacoes> _abrir(WidgetTester tester, UserSummary quem) async {
  final notificacoes = _Notificacoes();
  addTearDown(notificacoes.emissoes.close);
  final router = GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        builder: (_, __) =>
            const AutoEndNotice(child: Scaffold(body: Text('início'))),
      ),
      GoRoute(
        path: '/avaliacao/:eventId',
        builder: (_, s) =>
            Scaffold(body: Text('avaliação ${s.pathParameters['eventId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      notificationsRepositoryProvider.overrideWithValue(notificacoes),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return notificacoes;
}

Future<void> _emitir(
  WidgetTester tester,
  _Notificacoes notificacoes,
  List<AppNotification> lista,
) async {
  notificacoes.emissoes.add(lista);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o criador vê o aviso uma vez, e ele já fica lido',
      (tester) async {
    final notificacoes = await _abrir(tester, _dono);
    final aviso = _encerrado('evt_volei');

    await _emitir(tester, notificacoes, <AppNotification>[aviso]);

    expect(find.text(AppStrings.notificationAutoEndedTitle), findsOneWidget);
    expect(
      find.text(AppStrings.autoEndDialogBody('Vôlei dos Devs')),
      findsOneWidget,
    );
    expect(notificacoes.lidas, <String>['eventEnded_evt_volei']);

    await tester.tap(find.text(AppStrings.autoEndDialogLater));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.notificationAutoEndedTitle), findsNothing);
    expect(find.text('início'), findsOneWidget);

    // Uma emissão nova com o app aberto só mexe no badge.
    await _emitir(tester, notificacoes, <AppNotification>[
      aviso,
      _encerrado('evt_outro'),
    ]);
    expect(find.text(AppStrings.notificationAutoEndedTitle), findsNothing);
    expect(notificacoes.lidas, hasLength(1));
  });

  testWidgets('"Avaliar" abre a avaliação do evento', (tester) async {
    final notificacoes = await _abrir(tester, _dono);
    await _emitir(
        tester, notificacoes, <AppNotification>[_encerrado('evt_volei')]);

    await tester.tap(find.text(AppStrings.autoEndDialogRate));
    await tester.pumpAndSettle();

    expect(find.text('avaliação evt_volei'), findsOneWidget);
  });

  testWidgets('participante não vê o aviso', (tester) async {
    final notificacoes = await _abrir(tester, _participante);
    await _emitir(
        tester, notificacoes, <AppNotification>[_encerrado('evt_volei')]);

    expect(find.text(AppStrings.notificationAutoEndedTitle), findsNothing);
    expect(notificacoes.lidas, isEmpty);
  });

  testWidgets('encerramento manual não gera aviso', (tester) async {
    final notificacoes = await _abrir(tester, _dono);
    await _emitir(tester, notificacoes, <AppNotification>[
      _encerrado('evt_volei', automatico: false),
    ]);

    expect(find.text(AppStrings.notificationAutoEndedTitle), findsNothing);
  });

  testWidgets('aviso já lido não volta ao reabrir o app', (tester) async {
    final notificacoes = await _abrir(tester, _dono);
    await _emitir(tester, notificacoes, <AppNotification>[
      _encerrado('evt_volei', lida: true),
    ]);

    expect(find.text(AppStrings.notificationAutoEndedTitle), findsNothing);
  });

  testWidgets('primeira emissão sem aviso: os seguintes também não abrem',
      (tester) async {
    final notificacoes = await _abrir(tester, _dono);
    await _emitir(tester, notificacoes, const <AppNotification>[]);
    await _emitir(
        tester, notificacoes, <AppNotification>[_encerrado('evt_volei')]);

    expect(find.text(AppStrings.notificationAutoEndedTitle), findsNothing);
  });

  // Hipótese 7 da tarefa 14: o aviso envolve o scaffold do shell sem mexer
  // na troca de abas nem no estado guardado de cada uma.
  testWidgets('as abas do shell continuam guardando o próprio estado',
      (tester) async {
    final notificacoes = _Notificacoes();
    addTearDown(notificacoes.emissoes.close);
    final router = GoRouter(
      initialLocation: '/a',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => AutoEndNotice(
            child: Scaffold(
              body: shell,
              bottomNavigationBar: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => shell.goBranch(0),
                    child: const Text('aba A'),
                  ),
                  TextButton(
                    onPressed: () => shell.goBranch(1),
                    child: const Text('aba B'),
                  ),
                ],
              ),
            ),
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(path: '/a', builder: (_, __) => const _Contador()),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(path: '/b', builder: (_, __) => const Text('tela B')),
            ]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        currentUserSummaryProvider.overrideWith((ref) async => _dono),
        notificationsRepositoryProvider.overrideWithValue(notificacoes),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('somar'));
    await tester.tap(find.text('somar'));
    await tester.pump();
    expect(find.text('contagem 2'), findsOneWidget);

    await tester.tap(find.text('aba B'));
    await tester.pumpAndSettle();
    expect(find.text('tela B'), findsOneWidget);

    await tester.tap(find.text('aba A'));
    await tester.pumpAndSettle();
    expect(find.text('contagem 2'), findsOneWidget);
  });
}

class _Contador extends StatefulWidget {
  const _Contador();

  @override
  State<_Contador> createState() => _ContadorState();
}

class _ContadorState extends State<_Contador> {
  int _valor = 0;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text('contagem $_valor'),
          TextButton(
            onPressed: () => setState(() => _valor++),
            child: const Text('somar'),
          ),
        ],
      );
}
