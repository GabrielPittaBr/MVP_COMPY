import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/pages/event_detail_page.dart';
import 'package:mvp_compy/features/events/presentation/pages/live_event_page.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/home/presentation/providers/home_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_summary.dart';
import 'package:mvp_compy/features/ratings/presentation/providers/ratings_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

/// Exclusão pelo Organizador (#37) no detalhe e na tela ao vivo.

final _agora = DateTime(2026, 10, 21, 18);

const _dono = UserSummary(
  id: 'u_dono',
  name: 'Ana Souza',
  handle: '@anasouza',
  avatarUrl: '',
);
const _participante = UserSummary(
  id: 'u_participante',
  name: 'Bruno Lima',
  handle: '@brunolima',
  avatarUrl: '',
);

Event _evento({Duration inicioEm = const Duration(hours: 1), DateTime? endedAt}) =>
    Event(
      id: 'evt_x',
      title: 'Rachão',
      sport: Sport.basquete,
      location: 'Parque do Trabalhador, Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: _agora.add(inicioEm),
      durationMinutes: 60,
      skillLevel: SkillLevel.todos,
      totalSpots: 10,
      remainingSpots: 8,
      bannerUrl: '',
      creator: _dono,
      participants: const <UserSummary>[_dono, _participante],
      endedAt: endedAt,
    );

/// O documento some do stream quando a exclusão dá certo, como no Firestore.
class _Repositorio implements EventsRepository {
  _Repositorio(Event evento, {this.erro}) {
    documento.add(evento);
  }

  final StreamController<Event?> documento = StreamController<Event?>();
  final Object? erro;
  final List<(String, String?)> exclusoes = <(String, String?)>[];

  @override
  Stream<Event?> watchById(String id) => documento.stream;

  @override
  Future<void> deleteOwnEvent(String eventId, {String? reason}) async {
    exclusoes.add((eventId, reason));
    if (erro != null) throw erro!;
    documento.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Repositorio> _abrir(
  WidgetTester tester, {
  required UserSummary quem,
  Event? evento,
  bool aoVivo = false,
  Object? erro,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repositorio = _Repositorio(evento ?? _evento(), erro: erro);
  addTearDown(repositorio.documento.close);
  final router = GoRouter(
    initialLocation: aoVivo ? '/events/evt_x/ao-vivo' : '/events/evt_x',
    routes: <RouteBase>[
      GoRoute(
        path: '/events',
        builder: (_, __) => const Scaffold(body: Text('aba eventos')),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                EventDetailPage(eventId: state.pathParameters['id']!),
            routes: <RouteBase>[
              GoRoute(
                path: 'ao-vivo',
                builder: (_, state) =>
                    LiveEventPage(eventId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      eventsRepositoryProvider.overrideWithValue(repositorio),
      ratingSummaryProvider.overrideWith(
        (ref, target) => Stream<RatingSummary>.value(RatingSummary.empty),
      ),
      // As listas recarregadas depois da exclusão não importam aqui.
      paginatedEventsProvider.overrideWith(_SemEventos.new),
      myEventsProvider.overrideWith((ref) async => const <Event>[]),
      joinedActiveEventsProvider
          .overrideWith((ref) => Stream<List<Event>>.value(const <Event>[])),
      nearbyEventsProvider.overrideWith((ref) async => const <Event>[]),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return repositorio;
}

class _SemEventos extends PaginatedEventsController {
  @override
  Future<List<Event>> build() async => const <Event>[];
}

final _excluir = find.byTooltip(AppStrings.eventDelete);

Future<void> _abrirDialogo(WidgetTester tester) async {
  await tester.tap(_excluir);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('quem vê "Excluir evento"', () {
    testWidgets('o Organizador, no evento agendado, sem a denúncia',
        (tester) async {
      await _abrir(tester, quem: _dono);
      expect(_excluir, findsOneWidget);
      expect(find.byTooltip(AppStrings.reportEventTitle), findsNothing);
    });

    testWidgets('o Organizador, no evento acontecendo', (tester) async {
      await _abrir(tester,
          quem: _dono, evento: _evento(inicioEm: const Duration(minutes: -20)));
      expect(_excluir, findsOneWidget);
    });

    testWidgets('ninguém, no evento encerrado', (tester) async {
      await _abrir(tester,
          quem: _dono,
          evento: _evento(
            inicioEm: const Duration(hours: -3),
            endedAt: _agora.subtract(const Duration(hours: 2)),
          ));
      expect(_excluir, findsNothing);
    });

    testWidgets('não o participante, que vê a denúncia', (tester) async {
      await _abrir(tester, quem: _participante);
      expect(_excluir, findsNothing);
      expect(find.byTooltip(AppStrings.reportEventTitle), findsOneWidget);
    });

    for (final (quem, ve) in <(UserSummary, bool)>[
      (_dono, true),
      (_participante, false),
    ]) {
      testWidgets('na tela ao vivo, ${quem.name} ${ve ? 'vê' : 'não vê'}',
          (tester) async {
        await _abrir(tester,
            quem: quem,
            evento: _evento(inicioEm: const Duration(minutes: -20)),
            aoVivo: true);
        expect(find.text(AppStrings.eventLiveTitle), findsOneWidget);
        expect(_excluir, ve ? findsOneWidget : findsNothing);
      });
    }
  });

  group('diálogo', () {
    testWidgets('pede confirmação, e cancelar não exclui', (tester) async {
      final repositorio = await _abrir(tester, quem: _dono);

      await _abrirDialogo(tester);
      expect(find.text(AppStrings.eventDeleteConfirmTitle), findsOneWidget);
      expect(find.text(AppStrings.eventDeleteConfirmBody), findsOneWidget);
      expect(find.text(AppStrings.eventDeleteReasonLabel), findsOneWidget);

      await tester.tap(find.text(AppStrings.commonCancel));
      await tester.pumpAndSettle();
      expect(repositorio.exclusoes, isEmpty);
      expect(find.text(AppStrings.eventDeleteConfirmTitle), findsNothing);
    });

    testWidgets('confirmar exclui com o motivo e volta para a aba Eventos',
        (tester) async {
      final repositorio = await _abrir(tester, quem: _dono);

      await _abrirDialogo(tester);
      await tester.enterText(find.byType(TextField), 'Choveu.');
      await tester.tap(find.text(AppStrings.eventDeleteConfirm));
      await tester.pumpAndSettle();

      expect(repositorio.exclusoes, <(String, String?)>[('evt_x', 'Choveu.')]);
      expect(find.text('aba eventos'), findsOneWidget);
      expect(find.text(AppStrings.eventDeleted), findsOneWidget);
    });

    testWidgets('sem motivo, a exclusão vai sem motivo', (tester) async {
      final repositorio = await _abrir(tester, quem: _dono);

      await _abrirDialogo(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text(AppStrings.eventDeleteConfirm));
      await tester.pumpAndSettle();

      expect(repositorio.exclusoes, <(String, String?)>[('evt_x', null)]);
    });

    testWidgets('sem conexão, avisa e o motivo digitado fica', (tester) async {
      final repositorio = await _abrir(tester,
          quem: _dono, erro: const EventDeletionOfflineException());

      await _abrirDialogo(tester);
      await tester.enterText(find.byType(TextField), 'Choveu.');
      await tester.tap(find.text(AppStrings.eventDeleteConfirm));
      await tester.pumpAndSettle();

      expect(repositorio.exclusoes, hasLength(1));
      expect(find.text(AppStrings.eventDeleteOffline), findsOneWidget);
      expect(find.text(AppStrings.eventDeleteConfirmTitle), findsOneWidget);
      expect(find.text('Choveu.'), findsOneWidget);
      expect(find.text('aba eventos'), findsNothing);
    });

    testWidgets('o motivo tem até 200 caracteres', (tester) async {
      await _abrir(tester, quem: _dono);

      await _abrirDialogo(tester);
      await tester.enterText(find.byType(TextField), 'a' * 250);
      await tester.pump();

      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller!.text, hasLength(200));
    });
  });
}
