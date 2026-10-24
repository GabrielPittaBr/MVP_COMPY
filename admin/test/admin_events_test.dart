import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:compy_admin/features/events/data/admin_events_repository.dart';
import 'package:compy_admin/features/events/presentation/admin_events_controller.dart';
import 'package:compy_admin/features/events/presentation/admin_events_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 23, 12);
const _reason = 'Evento falso denunciado por participantes.';

void main() {
  group('leitura de events/{id}', () {
    test('lê o documento novo com local, vagas e ciclo de vida', () {
      final event = AdminEventRecord.fromDocument('evt-1', <String, dynamic>{
        'title': 'Pelada de quinta',
        'sport': 'futebol',
        'skillLevel': 'iniciante',
        'dateTime': Timestamp.fromDate(DateTime(2026, 10, 23, 19)),
        'endsAt': Timestamp.fromDate(DateTime(2026, 10, 23, 20, 30)),
        'location': 'Parque do Trabalhador, Taquara',
        'placeId': 'parque',
        'placeSnapshot': <String, Object?>{
          'name': 'Parque do Trabalhador',
          'address': <String, Object?>{
            'street': 'Rua Tristão Monteiro',
            'number': '1200',
            'neighborhood': 'Centro',
            'city': 'Taquara',
            'state': 'RS',
          },
        },
        'totalSpots': 10,
        'remainingSpots': 7,
        'creator': <String, Object?>{'id': 'uid-org', 'name': 'Ana'},
        'participants': <Object?>[
          <String, Object?>{'id': 'uid-org', 'name': 'Ana'},
          <String, Object?>{'id': 'uid-b', 'name': 'Bruno'},
          'lixo',
          <String, Object?>{'name': 'sem id'},
        ],
        'ratedBy': <Object?>['uid-b', 42],
      });

      expect(event.placeName, 'Parque do Trabalhador');
      expect(
        event.placeAddress,
        'Rua Tristão Monteiro, 1200 – Centro – Taquara/RS',
      );
      expect(event.endsAt, DateTime(2026, 10, 23, 20, 30));
      expect(event.organizer?.uid, 'uid-org');
      expect(event.participants.map((person) => person.uid), <String>[
        'uid-org',
        'uid-b',
      ]);
      expect(event.ratedByCount, 1);
    });

    test('documento legado sem endsAt usa a duração, ou 1h', () {
      final withDuration = AdminEventRecord.fromDocument('a', <String, dynamic>{
        'dateTime': Timestamp.fromDate(DateTime(2026, 10, 23, 9)),
        'durationMinutes': 90,
      });
      final legacy = AdminEventRecord.fromDocument('b', <String, dynamic>{
        'dateTime': Timestamp.fromDate(DateTime(2026, 10, 23, 9)),
      });
      final empty = AdminEventRecord.fromDocument('c', <String, dynamic>{});

      expect(withDuration.endsAt, DateTime(2026, 10, 23, 10, 30));
      expect(legacy.endsAt, DateTime(2026, 10, 23, 10));
      expect(empty.startsAt, isNull);
      expect(empty.organizer, isNull);
      expect(empty.participants, isEmpty);
    });

    test('a fase segue a regra do app, com a folga de 1h', () {
      AdminEventRecord at(DateTime start, {DateTime? endedAt}) =>
          AdminEventRecord.fromDocument('e', <String, dynamic>{
            'dateTime': Timestamp.fromDate(start),
            'endsAt': Timestamp.fromDate(start.add(const Duration(hours: 1))),
            if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt),
          });

      expect(
        at(_now.add(const Duration(hours: 1))).statusAt(_now),
        AdminEventStatus.scheduled,
      );
      expect(
        at(_now.subtract(const Duration(minutes: 30))).statusAt(_now),
        AdminEventStatus.happening,
      );
      // Passou do fim previsto, mas ainda dentro da folga.
      expect(
        at(_now.subtract(const Duration(minutes: 90))).statusAt(_now),
        AdminEventStatus.happening,
      );
      expect(
        at(_now.subtract(const Duration(hours: 3))).statusAt(_now),
        AdminEventStatus.ended,
      );
      expect(
        at(
          _now.subtract(const Duration(minutes: 30)),
          endedAt: _now,
        ).statusAt(_now),
        AdminEventStatus.ended,
      );
      expect(
        AdminEventRecord.fromDocument('x', <String, dynamic>{}).statusAt(_now),
        AdminEventStatus.ended,
      );
    });

    test('busca por título usa o titleLower do app, que mantém acentos', () {
      final plan = AdminEventsQueryPlan.fromFilters(
        const AdminEventsFilters(titlePrefix: '  Vôlei NA ', sport: 'volei'),
      );

      expect(plan.titlePrefix, 'vôlei na');
      expect(plan.ordersByTitle, isTrue);
      expect(plan.sport, 'volei');
      expect(
        AdminEventsQueryPlan.fromFilters(const AdminEventsFilters())
            .ordersByTitle,
        isFalse,
      );
      expect(AdminEventsQueryPlan.pageSize, 20);
    });

    test('exclusão envia somente o contrato idempotente aprovado', () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = FirebaseAdminEventsRepository(
        invoker: (name, payload) async {
          calls.add((name, Map<String, Object?>.from(payload)));
          return <String, Object?>{
            'eventId': 'evt-1',
            'completedAt': '2026-10-23T12:00:00.000Z',
          };
        },
      );

      final result = await repository.deleteEvent(
        eventId: 'evt-1',
        reason: '  Evento   falso  denunciado ',
        operationId: 'a04988af-ccba-4c4e-a0d2-df5c56be31d6',
      );

      expect(calls.single.$1, 'deleteEvent');
      expect(calls.single.$2, <String, Object?>{
        'eventId': 'evt-1',
        'reason': 'Evento falso denunciado',
        'operationId': 'a04988af-ccba-4c4e-a0d2-df5c56be31d6',
      });
      expect(result.completedAt, DateTime.utc(2026, 10, 23, 12));
      expect(
        () => AdminEventDeletionResult.fromCallable(<String, Object?>{
          'eventId': 'evt-1',
        }),
        throwsFormatException,
      );
    });
  });

  group('AdminEventsController', () {
    test('pagina pelo cursor e recomeça ao trocar os filtros', () async {
      final cursor = _Cursor();
      final repo = _FakeEventsRepository()
        ..pages.addAll(<AdminEventsPageSnapshot>[
          AdminEventsPageSnapshot(
            events: <AdminEventRecord>[_event('a'), _event('b')],
            cursor: cursor,
            isFromCache: false,
          ),
          AdminEventsPageSnapshot(
            events: <AdminEventRecord>[_event('b'), _event('c')],
            cursor: null,
            isFromCache: true,
          ),
        ]);
      final controller = AdminEventsController(repo)..start();
      await pumpEventQueue();

      expect(controller.state.events.map((event) => event.id), <String>[
        'a',
        'b',
      ]);
      expect(controller.state.hasMore, isTrue);

      await controller.loadNextPage();
      expect(repo.searchCalls.last.after, same(cursor));
      expect(controller.state.events.map((event) => event.id), <String>[
        'a',
        'b',
        'c',
      ]);
      expect(controller.state.hasMore, isFalse);
      expect(controller.state.isFromCache, isTrue);

      controller.updateFilters(const AdminEventsFilters(sport: 'futebol'));
      await pumpEventQueue();
      expect(repo.searchCalls.last.filters.sport, 'futebol');
      expect(repo.searchCalls.last.after, isNull);
      expect(controller.state.events, isEmpty);
      controller.dispose();
    });
  });

  group('lista de Eventos Esportivos', () {
    testWidgets('mostra a fase, o local, quem organizou e as vagas', (
      tester,
    ) async {
      final repo = _FakeEventsRepository()
        ..pages.add(
          AdminEventsPageSnapshot(
            events: <AdminEventRecord>[
              _event(
                'agendado',
                title: 'Vôlei de sábado',
                start: _now.add(const Duration(days: 1)),
              ),
              _event(
                'agora',
                title: 'Corrida no parque',
                sport: 'corrida',
                start: _now.subtract(const Duration(minutes: 10)),
              ),
              _event(
                'passado',
                title: 'Futsal antigo',
                start: _now.subtract(const Duration(days: 3)),
              ),
            ],
            cursor: null,
            isFromCache: false,
          ),
        );
      await _pumpList(tester, repo);

      expect(find.text('Eventos Esportivos'), findsOneWidget);
      expect(find.text('Vôlei de sábado'), findsOneWidget);
      expect(find.text('Agendado'), findsOneWidget);
      expect(find.text('Acontecendo'), findsOneWidget);
      expect(find.text('Encerrado'), findsOneWidget);
      expect(find.textContaining('Organizado por Ana'), findsNWidgets(3));
      expect(
        find.textContaining('3 de 10 vagas preenchidas'),
        findsNWidgets(3),
      );
      expect(
        find.textContaining('Corrida · Parque do Trabalhador'),
        findsOneWidget,
      );
    });

    testWidgets('filtro de modalidade consulta de novo e o vazio explica', (
      tester,
    ) async {
      final repo = _FakeEventsRepository()
        ..pages.add(
          AdminEventsPageSnapshot(
            events: <AdminEventRecord>[_event('a')],
            cursor: null,
            isFromCache: false,
          ),
        );
      await _pumpList(tester, repo);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Basquete').last);
      await tester.pumpAndSettle();

      expect(repo.searchCalls.last.filters.sport, 'basquete');
      expect(
        find.text('Nenhum evento corresponde aos filtros.'),
        findsOneWidget,
      );
    });

    testWidgets('busca por título espera a digitação terminar', (tester) async {
      final repo = _FakeEventsRepository();
      await _pumpList(tester, repo);

      await tester.enterText(find.byType(TextField), 'Pel');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.searchCalls, hasLength(1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repo.searchCalls, hasLength(2));
      expect(repo.searchCalls.last.filters.titlePrefix, 'Pel');
    });

    testWidgets('erro oferece nova tentativa', (tester) async {
      final repo = _FakeEventsRepository()..failNext = true;
      await _pumpList(tester, repo);

      expect(
        find.text('Não foi possível carregar os eventos.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(repo.searchCalls, hasLength(2));
      expect(
        find.text('Nenhum Evento Esportivo criado ainda.'),
        findsOneWidget,
      );
    });
  });

  group('detalhes e exclusão do evento', () {
    testWidgets('mostra dados, organizador e participantes', (tester) async {
      final repo = _FakeEventsRepository()..detail = _event('evt-1');
      await _pumpDetails(tester, repo);

      expect(find.text('Pelada de quinta'), findsOneWidget);
      expect(find.text('Agendado'), findsOneWidget);
      expect(find.text('Futebol'), findsOneWidget);
      expect(find.text('Iniciante'), findsOneWidget);
      expect(find.textContaining('Parque do Trabalhador'), findsWidgets);
      expect(find.text('Participantes (3)'), findsOneWidget);
      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Organizador'), findsWidgets);
      expect(find.text('Excluir evento'), findsWidgets);
    });

    testWidgets('evento inexistente não oferece ações', (tester) async {
      await _pumpDetails(tester, _FakeEventsRepository());

      expect(find.text('Evento não encontrado.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('valida o motivo antes da confirmação', (tester) async {
      final repo = _FakeEventsRepository()..detail = _event('evt-1');
      await _pumpDetails(tester, repo);

      await tester.enterText(find.byType(TextField), 'curto');
      await _tapDelete(tester);

      expect(find.textContaining('10 a 500 caracteres'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.deletionCalls, isEmpty);
    });

    testWidgets('confirma com reconhecimento explícito e encerra a página', (
      tester,
    ) async {
      final repo = _FakeEventsRepository()..detail = _event('evt-1');
      await _pumpDetails(tester, repo);
      await tester.enterText(find.byType(TextField), _reason);
      await _tapDelete(tester);

      expect(find.text('Excluir evento?'), findsOneWidget);
      expect(find.text('ID: evt-1'), findsWidgets);
      expect(find.text('Motivo: $_reason'), findsWidgets);
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Excluir evento'),
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(repo.deletionCalls.single.eventId, 'evt-1');
      expect(repo.deletionCalls.single.reason, _reason);
      expect(find.text('Evento excluído.'), findsWidgets);
      expect(find.text('Voltar para Eventos'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('resultado incerto repete com o mesmo operationId', (
      tester,
    ) async {
      var attempts = 0;
      final repo = _FakeEventsRepository()
        ..detail = _event('evt-1')
        ..deletionHandler = (eventId) async {
          attempts++;
          if (attempts == 1) {
            throw FirebaseFunctionsException(
              code: 'internal',
              message: 'x',
              details: <String, Object?>{'operationStatus': 'pending'},
            );
          }
          return AdminEventDeletionResult(
            eventId: eventId,
            completedAt: DateTime.utc(2026, 10, 23),
          );
        };
      await _pumpDetails(tester, repo);
      await tester.enterText(find.byType(TextField), _reason);

      await _confirmDeletion(tester);
      expect(
        find.textContaining('repetirá a mesma solicitação'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await _confirmDeletion(tester);
      expect(repo.deletionCalls, hasLength(2));
      expect(
        repo.deletionCalls.last.operationId,
        repo.deletionCalls.first.operationId,
      );
      expect(find.text('Voltar para Eventos'), findsOneWidget);
    });

    testWidgets('evento já excluído por outra via encerra a página', (
      tester,
    ) async {
      final repo = _FakeEventsRepository()
        ..detail = _event('evt-1')
        ..deletionHandler = (_) async {
          throw FirebaseFunctionsException(
            code: 'not-found',
            message: 'x',
            details: <String, Object?>{'operationStatus': 'failed'},
          );
        };
      await _pumpDetails(tester, repo);
      await tester.enterText(find.byType(TextField), _reason);
      await _confirmDeletion(tester);

      expect(find.text('Este evento já não existe.'), findsOneWidget);
    });

    testWidgets('servidor em andamento trava o botão e avisa', (tester) async {
      final completer = Completer<AdminEventDeletionResult>();
      final repo = _FakeEventsRepository()
        ..detail = _event('evt-1')
        ..deletionHandler = (_) => completer.future;
      await _pumpDetails(tester, repo);
      await tester.enterText(find.byType(TextField), _reason);
      await _tapDelete(tester);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Excluir evento'),
        ),
      );
      await tester.pump();
      // O spinner gira sem parar: só espera o diálogo terminar de fechar.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Aguardando confirmação'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Excluir evento'),
            )
            .onPressed,
        isNull,
      );

      completer.complete(
        AdminEventDeletionResult(
          eventId: 'evt-1',
          completedAt: DateTime.utc(2026, 10, 23),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voltar para Eventos'), findsOneWidget);
    });
  });
}

AdminEventRecord _event(
  String id, {
  String title = 'Pelada de quinta',
  String sport = 'futebol',
  DateTime? start,
}) {
  final startsAt = start ?? _now.add(const Duration(days: 2));
  return AdminEventRecord.fromDocument(id, <String, dynamic>{
    'title': title,
    'sport': sport,
    'skillLevel': 'iniciante',
    'dateTime': Timestamp.fromDate(startsAt),
    'endsAt': Timestamp.fromDate(startsAt.add(const Duration(hours: 1))),
    'placeSnapshot': <String, Object?>{
      'name': 'Parque do Trabalhador',
      'address': <String, Object?>{
        'street': 'Rua Tristão Monteiro',
        'city': 'Taquara',
        'state': 'RS',
      },
    },
    'totalSpots': 10,
    'remainingSpots': 7,
    'creator': <String, Object?>{
      'id': 'uid-org',
      'name': 'Ana',
      'handle': '@ana',
    },
    'participants': <Object?>[
      <String, Object?>{'id': 'uid-org', 'name': 'Ana', 'handle': '@ana'},
      <String, Object?>{'id': 'uid-b', 'name': 'Bruno', 'handle': '@bruno'},
      <String, Object?>{'id': 'uid-c', 'name': 'Carla', 'handle': '@carla'},
    ],
  });
}

Future<void> _pumpList(WidgetTester tester, _FakeEventsRepository repo) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminEventsPage(repository: repo, clock: () => _now),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetails(
  WidgetTester tester,
  _FakeEventsRepository repo,
) async {
  tester.view.physicalSize = const Size(1100, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminEventDetailsPage(
          eventId: 'evt-1',
          repository: repo,
          clock: () => _now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapDelete(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Excluir evento');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _confirmDeletion(WidgetTester tester) async {
  await _tapDelete(tester);
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Excluir evento'),
    ),
  );
  await tester.pumpAndSettle();
}

class _Cursor implements AdminEventCursor {}

class _SearchCall {
  const _SearchCall(this.filters, this.after);
  final AdminEventsFilters filters;
  final AdminEventCursor? after;
}

class _DeletionCall {
  const _DeletionCall(this.eventId, this.reason, this.operationId);
  final String eventId;
  final String reason;
  final String operationId;
}

class _FakeEventsRepository implements AdminEventsRepository {
  final List<AdminEventsPageSnapshot> pages = <AdminEventsPageSnapshot>[];
  final List<_SearchCall> searchCalls = <_SearchCall>[];
  final List<_DeletionCall> deletionCalls = <_DeletionCall>[];
  AdminEventRecord? detail;
  bool failNext = false;
  Future<AdminEventDeletionResult> Function(String eventId)? deletionHandler;

  @override
  Future<AdminEventsPageSnapshot> searchEvents(
    AdminEventsFilters filters, {
    AdminEventCursor? after,
  }) async {
    searchCalls.add(_SearchCall(filters, after));
    if (failNext) {
      failNext = false;
      throw StateError('temporário');
    }
    if (pages.isEmpty) {
      return const AdminEventsPageSnapshot(
        events: <AdminEventRecord>[],
        cursor: null,
        isFromCache: false,
      );
    }
    return pages.removeAt(0);
  }

  @override
  Future<AdminEventRecord?> loadEvent(String id) async => detail;

  @override
  Future<List<AdminEventRecord>> loadOrganizedBy(
    String uid, {
    int limit = AdminEventsQueryPlan.pageSize,
  }) async => const <AdminEventRecord>[];

  @override
  Future<AdminEventDeletionResult> deleteEvent({
    required String eventId,
    required String reason,
    required String operationId,
  }) {
    deletionCalls.add(_DeletionCall(eventId, reason, operationId));
    final handler = deletionHandler;
    if (handler != null) return handler(eventId);
    return Future<AdminEventDeletionResult>.value(
      AdminEventDeletionResult(
        eventId: eventId,
        completedAt: DateTime.utc(2026, 10, 23),
      ),
    );
  }
}
