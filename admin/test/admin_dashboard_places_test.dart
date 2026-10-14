import 'dart:async';

import 'package:compy_admin/features/dashboard/data/admin_dashboard_repository.dart';
import 'package:compy_admin/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:compy_admin/features/places/data/admin_places_repository.dart';
import 'package:compy_admin/features/places/presentation/admin_places_controller.dart';
import 'package:compy_admin/features/places/presentation/admin_places_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dashboard administrativo', () {
    test('usa aggregates de perfis e contagens de places por status', () {
      expect(
        AdminDashboardCountQuery.definitions,
        const <AdminDashboardCountQuery>[
          AdminDashboardCountQuery(collection: 'users'),
          AdminDashboardCountQuery(
            collection: 'places',
            filterField: 'status',
            filterValue: 'active',
          ),
          AdminDashboardCountQuery(
            collection: 'places',
            filterField: 'status',
            filterValue: 'inactive',
          ),
        ],
      );
    });

    testWidgets('mostra contagens curadas, semântica e atalhos', (
      tester,
    ) async {
      final repository = _FakeDashboardRepository(
        const AdminDashboardMetrics(
          profileCount: 42,
          activePlaceCount: 7,
          inactivePlaceCount: 2,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminDashboardPage(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(find.text('Usuários cadastrados'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Contagem de perfis Firestore'), findsOneWidget);
      expect(find.text('Cadastrar local'), findsOneWidget);
      expect(find.text('Ver locais inativos'), findsOneWidget);
      expect(find.text('Buscar usuário'), findsOneWidget);
    });

    testWidgets('erro oferece retry sem confundir com contagem zero', (
      tester,
    ) async {
      final repository = _FakeDashboardRepository.errorThen(
        const AdminDashboardMetrics(
          profileCount: 1,
          activePlaceCount: 2,
          inactivePlaceCount: 3,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminDashboardPage(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar os indicadores.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('Consulta administrativa de locais', () {
    test('normalização de busca corresponde ao contrato pt-BR', () {
      expect(
        normalizeAdminSearch('  PARQUE DO TRABALHADOR '),
        'parque do trabalhador',
      );
      expect(normalizeAdminSearch('Tênis de MESA'), 'tenis de mesa');
    });

    test('plano aplica filtros combinados e páginas fixas de 20', () {
      final plan = AdminPlacesQueryPlan.fromFilters(
        const AdminPlacesFilters(
          namePrefix: 'parque',
          status: AdminPlaceStatusFilter.active,
          sport: 'corrida',
          cityLower: 'taquara',
        ),
      );
      expect(plan.status, 'active');
      expect(plan.sport, 'corrida');
      expect(plan.cityLower, 'taquara');
      expect(plan.namePrefix, 'parque');
      expect(AdminPlacesQueryPlan.pageSize, 20);
      expect(
        AdminPlacesQueryPlan.fromFilters(const AdminPlacesFilters()).status,
        isNull,
      );
    });

    test(
      'controller encaminha filtros combinados e pagina pelo cursor',
      () async {
        final repository = _FakePlacesRepository();
        final controller = AdminPlacesController(repository)..start();
        await _flush();
        final firstCursor = _Cursor();
        repository.streams[0].add(
          AdminPlacesPageSnapshot(
            places: List<AdminPlaceSummary>.generate(
              20,
              (index) => _place('$index'),
            ),
            cursor: firstCursor,
            isFromCache: true,
          ),
        );
        await _flush();
        expect(controller.state.places, hasLength(20));
        expect(controller.state.hasMore, isTrue);
        expect(controller.state.isFromCache, isTrue);

        controller.updateFilters(
          const AdminPlacesFilters(
            namePrefix: 'parque',
            status: AdminPlaceStatusFilter.inactive,
            sport: 'futebol',
            cityLower: 'taquara',
          ),
        );
        await _flush();
        expect(
          repository.calls.last.filters,
          const AdminPlacesFilters(
            namePrefix: 'parque',
            status: AdminPlaceStatusFilter.inactive,
            sport: 'futebol',
            cityLower: 'taquara',
          ),
        );
        expect(controller.state.places, isEmpty);

        repository.streams.last.add(
          AdminPlacesPageSnapshot(
            places: List<AdminPlaceSummary>.generate(
              20,
              (index) => _place('filtered-$index'),
            ),
            cursor: firstCursor,
            isFromCache: false,
          ),
        );
        await _flush();
        controller.loadNextPage();
        await _flush();
        expect(repository.calls.last.cursor, same(firstCursor));
        repository.streams.last.add(
          const AdminPlacesPageSnapshot(
            places: <AdminPlaceSummary>[
              AdminPlaceSummary(
                id: 'next',
                name: 'Outro local',
                nameLower: 'outro local',
                city: 'Taquara',
                state: 'RS',
                sports: <String>['corrida'],
                status: 'inactive',
              ),
            ],
            cursor: null,
            isFromCache: false,
          ),
        );
        await _flush();
        expect(controller.state.places, hasLength(21));
        expect(controller.state.hasMore, isFalse);
        controller.dispose();
      },
    );

    test(
      'snapshot atualiza em tempo real sem perder a página carregada',
      () async {
        final repository = _FakePlacesRepository();
        final controller = AdminPlacesController(repository)..start();
        await _flush();
        repository.streams.first.add(
          AdminPlacesPageSnapshot(
            places: <AdminPlaceSummary>[_place('live')],
            cursor: null,
            isFromCache: false,
          ),
        );
        await _flush();
        repository.streams.first.add(
          const AdminPlacesPageSnapshot(
            places: <AdminPlaceSummary>[
              AdminPlaceSummary(
                id: 'live',
                name: 'Local atualizado',
                nameLower: 'local live',
                city: 'Taquara',
                state: 'RS',
                sports: <String>['futebol'],
                status: 'active',
              ),
            ],
            cursor: null,
            isFromCache: false,
          ),
        );
        await _flush();
        expect(controller.state.places.single.name, 'Local atualizado');
        expect(repository.calls, hasLength(1));
        controller.dispose();
      },
    );

    test('mudança de membership reinicia cursor para preservar páginas consistentes', () async {
      final repository = _FakePlacesRepository();
      final controller = AdminPlacesController(repository)..start();
      await _flush();
      final cursor = _Cursor();
      repository.streams.first.add(
        AdminPlacesPageSnapshot(
          places: List<AdminPlaceSummary>.generate(
            20,
            (index) => _place('$index'),
          ),
          cursor: cursor,
          isFromCache: false,
        ),
      );
      await _flush();
      controller.loadNextPage();
      await _flush();
      repository.streams.last.add(
        const AdminPlacesPageSnapshot(
          places: <AdminPlaceSummary>[
            AdminPlaceSummary(
              id: 'new-first-page-item',
              name: 'Novo',
              nameLower: 'novo',
              city: 'Taquara',
              state: 'RS',
              sports: <String>['futebol'],
              status: 'active',
            ),
          ],
          cursor: null,
          isFromCache: false,
        ),
      );
      await _flush();
      repository.streams.first.add(
        const AdminPlacesPageSnapshot(
          places: <AdminPlaceSummary>[],
          cursor: null,
          isFromCache: false,
        ),
      );
      await _flush();
      expect(repository.calls, hasLength(3));
      expect(controller.state.places, isEmpty);
      controller.dispose();
    });

    testWidgets('lista diferencia cache, resultado vazio e erro com retry', (
      tester,
    ) async {
      final repository = _FakePlacesRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminPlacesPage(repository: repository)),
        ),
      );
      expect(
        find.bySemanticsLabel('Carregando Locais Esportivos'),
        findsOneWidget,
      );
      repository.streams.first.add(
        const AdminPlacesPageSnapshot(
          places: <AdminPlaceSummary>[],
          cursor: null,
          isFromCache: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Exibindo dados em cache'), findsOneWidget);
      expect(find.text('Nenhum Local Esportivo cadastrado.'), findsOneWidget);

      repository.streams.first.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível carregar os locais.'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(repository.calls, hasLength(2));
    });

    testWidgets('filtros têm rótulos acessíveis para tecnologia assistiva', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPlacesPage(repository: _FakePlacesRepository()),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Buscar por nome'), findsWidgets);
      expect(find.bySemanticsLabel('Filtro: Status'), findsWidgets);
      expect(find.bySemanticsLabel('Filtro: Modalidade'), findsWidgets);
      expect(find.bySemanticsLabel('Filtro: Cidade exata'), findsWidgets);
      semantics.dispose();
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
}

AdminPlaceSummary _place(String id) => AdminPlaceSummary(
  id: id,
  name: 'Local $id',
  nameLower: 'local $id',
  city: 'Taquara',
  state: 'RS',
  sports: const <String>['futebol'],
  status: 'active',
);

class _Cursor implements AdminPlaceCursor {}

class _FakeDashboardRepository implements AdminDashboardRepository {
  _FakeDashboardRepository(this.metrics) : _errorFirst = false;

  _FakeDashboardRepository.errorThen(this.metrics) : _errorFirst = true;

  final AdminDashboardMetrics metrics;
  final bool _errorFirst;
  int calls = 0;

  @override
  Future<AdminDashboardMetrics> loadMetrics() async {
    calls += 1;
    if (_errorFirst && calls == 1) throw StateError('temporary');
    return metrics;
  }
}

class _FakePlacesRepository implements AdminPlacesRepository {
  final List<_WatchCall> calls = <_WatchCall>[];
  final List<StreamController<AdminPlacesPageSnapshot>> streams =
      <StreamController<AdminPlacesPageSnapshot>>[];

  @override
  Stream<AdminPlacesPageSnapshot> watchPage(
    AdminPlacesFilters filters, {
    AdminPlaceCursor? after,
  }) {
    calls.add(_WatchCall(filters, after));
    final stream = StreamController<AdminPlacesPageSnapshot>.broadcast();
    streams.add(stream);
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WatchCall {
  const _WatchCall(this.filters, this.cursor);

  final AdminPlacesFilters filters;
  final AdminPlaceCursor? cursor;
}
