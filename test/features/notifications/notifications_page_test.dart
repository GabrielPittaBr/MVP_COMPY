import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/features/notifications/domain/entities/app_notification.dart';
import 'package:mvp_compy/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mvp_compy/features/notifications/presentation/pages/notifications_page.dart';
import 'package:mvp_compy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

final _agora = DateTime(2026, 10, 21, 20, 30);

const _eu = UserSummary(
  id: 'u_bruno',
  name: 'Bruno Lima',
  handle: '@brunolima',
  avatarUrl: '',
);

AppNotification _notificacao(
  String eventId,
  String titulo, {
  required Duration ha,
  bool lida = false,
  bool avaliada = false,
}) =>
    AppNotification(
      id: 'eventEnded_$eventId',
      type: AppNotificationType.eventEnded,
      eventId: eventId,
      eventTitle: titulo,
      sport: 'basquete',
      creatorId: 'u_dono',
      endedAutomatically: false,
      createdAt: _agora.subtract(ha),
      readAt: lida || avaliada ? _agora.subtract(ha) : null,
      completedAt: avaliada ? _agora.subtract(ha) : null,
    );

class _Notificacoes implements NotificationsRepository {
  _Notificacoes(this.lista);

  final List<AppNotification> lista;
  final List<String> lidas = <String>[];
  final List<List<String>> lotes = <List<String>>[];

  @override
  Stream<List<AppNotification>> watch(String uid) => Stream.value(lista);

  @override
  Future<void> markRead(String uid, String notificationId) async =>
      lidas.add(notificationId);

  @override
  Future<void> markAllRead(String uid, Iterable<String> ids) async =>
      lotes.add(ids.toList());
}

Future<void> _abrir(WidgetTester tester, _Notificacoes repositorio) async {
  final router = GoRouter(
    initialLocation: '/home/notificacoes',
    routes: <RouteBase>[
      GoRoute(
        path: '/home/notificacoes',
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/avaliacao/:eventId',
        builder: (_, s) =>
            Scaffold(body: Text('avaliação ${s.pathParameters['eventId']}')),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (_, s) =>
            Scaffold(body: Text('detalhe ${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => _eu),
      notificationsRepositoryProvider.overrideWithValue(repositorio),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final rachao =
      _notificacao('evt_rachao', 'Rachão', ha: const Duration(minutes: 12));
  final pelada = _notificacao(
    'evt_pelada',
    'Peladinha de Quinta',
    ha: const Duration(days: 1),
    avaliada: true,
  );
  final caminhada = _notificacao(
    'evt_caminhada',
    'Caminhada',
    ha: const Duration(days: 3),
    lida: true,
  );

  testWidgets('separa Novas e Anteriores, com tempo e "Avaliado"',
      (tester) async {
    await _abrir(
        tester, _Notificacoes(<AppNotification>[rachao, pelada, caminhada]));

    expect(find.text(AppStrings.notificationsNew), findsOneWidget);
    expect(find.text(AppStrings.notificationsEarlier), findsOneWidget);
    expect(find.text('Rachão terminou'), findsOneWidget);
    expect(find.text('há 12 min'), findsOneWidget);
    expect(find.text('ontem'), findsOneWidget);
    expect(find.text('há 3 dias'), findsOneWidget);
    expect(find.text(AppStrings.notificationRated), findsOneWidget);
    expect(find.text(AppStrings.notificationsMarkAllRead), findsOneWidget);
  });

  testWidgets('tocar numa não avaliada marca como lida e abre a avaliação',
      (tester) async {
    final repositorio = _Notificacoes(<AppNotification>[rachao, pelada]);
    await _abrir(tester, repositorio);

    await tester.tap(find.text('Rachão terminou'));
    await tester.pumpAndSettle();

    expect(repositorio.lidas, <String>['eventEnded_evt_rachao']);
    expect(find.text('avaliação evt_rachao'), findsOneWidget);
  });

  testWidgets('tocar numa já avaliada abre o detalhe', (tester) async {
    final repositorio = _Notificacoes(<AppNotification>[rachao, pelada]);
    await _abrir(tester, repositorio);

    await tester.tap(find.text('Peladinha de Quinta terminou'));
    await tester.pumpAndSettle();

    expect(repositorio.lidas, isEmpty);
    expect(find.text('detalhe evt_pelada'), findsOneWidget);
  });

  testWidgets('"Marcar todas como lidas" manda só as não lidas, num lote',
      (tester) async {
    final segunda =
        _notificacao('evt_volei', 'Vôlei', ha: const Duration(hours: 2));
    final repositorio =
        _Notificacoes(<AppNotification>[rachao, segunda, caminhada]);
    await _abrir(tester, repositorio);

    await tester.tap(find.text(AppStrings.notificationsMarkAllRead));
    await tester.pumpAndSettle();

    expect(repositorio.lotes, <List<String>>[
      <String>['eventEnded_evt_rachao', 'eventEnded_evt_volei'],
    ]);
  });

  testWidgets('sem notificações, o estado vazio', (tester) async {
    await _abrir(tester, _Notificacoes(const <AppNotification>[]));

    expect(find.text(AppStrings.notificationsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.notificationsEmptyBody), findsOneWidget);
  });
}
