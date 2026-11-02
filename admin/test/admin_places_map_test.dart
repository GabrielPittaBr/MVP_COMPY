import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compy_admin/core/theme/admin_colors.dart';
import 'package:compy_admin/features/places/data/admin_place_model.dart';
import 'package:compy_admin/features/places/data/admin_places_repository.dart';
import 'package:compy_admin/features/places/presentation/admin_places_map.dart';
import 'package:compy_admin/features/places/presentation/admin_places_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Mapa geral dos locais', () {
    testWidgets('Mapa mostra um pin por local, com inativos em cinza', (
      tester,
    ) async {
      _useDesktopSize(tester);
      final repository = _FakePlacesRepository();
      await _pumpPage(tester, repository);

      await _openMap(tester);
      expect(repository.watchAllCalls, <AdminPlacesFilters>[
        const AdminPlacesFilters(),
      ]);
      expect(
        find.bySemanticsLabel('Carregando mapa dos locais'),
        findsOneWidget,
      );
      repository.emitAll(<AdminPlaceRecord>[
        _record('a', 'Praça A', -29.651, -50.781),
        _record('b', 'Ginásio B', -29.662, -50.792),
        _record('c', 'Quadra C', -29.646, -50.775, status: 'inactive'),
      ]);
      await tester.pumpAndSettle();

      expect(_pins(), findsNWidgets(3));
      expect(find.text('3 locais no mapa'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(_pinColor(tester, 'a'), AdminColors.primary);
      expect(_pinColor(tester, 'c'), AdminColors.outline);
      expect(find.text('Praça A'), findsNothing);
    });

    testWidgets('Mostrar nomes deixa o nome de todos os locais no mapa', (
      tester,
    ) async {
      _useDesktopSize(tester);
      final repository = _FakePlacesRepository();
      await _pumpPage(tester, repository);
      await _openMap(tester);
      repository.emitAll(<AdminPlaceRecord>[
        _record('a', 'Praça A', -29.651, -50.781),
        _record('b', 'Ginásio B', -29.662, -50.792),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mostrar nomes'));
      await tester.pumpAndSettle();
      expect(find.text('Praça A'), findsOneWidget);
      expect(find.text('Ginásio B'), findsOneWidget);
    });

    testWidgets('mudar o filtro com o mapa aberto relê os locais', (
      tester,
    ) async {
      _useDesktopSize(tester);
      final repository = _FakePlacesRepository();
      await _pumpPage(tester, repository);
      await _openMap(tester);
      repository.emitAll(<AdminPlaceRecord>[
        _record('a', 'Praça A', -29.651, -50.781),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byType(DropdownButtonFormField<AdminPlaceStatusFilter>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ativos').last);
      await tester.pump();

      expect(repository.watchAllCalls, hasLength(2));
      expect(
        repository.watchAllCalls.last.status,
        AdminPlaceStatusFilter.active,
      );
    });

    testWidgets('o mapa abre enquadrando locais distantes entre si', (
      tester,
    ) async {
      _useDesktopSize(tester);
      final points = <String, LatLng>{
        'taquara': const LatLng(-29.651, -50.781),
        'poa': const LatLng(-30.034, -51.217),
      };
      await _pumpMap(tester, <AdminPlaceRecord>[
        for (final MapEntry(:key, :value) in points.entries)
          _record(key, 'Local $key', value.latitude, value.longitude),
      ]);

      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      for (final point in points.values) {
        expect(camera.visibleBounds.contains(point), isTrue);
      }
      expect(_pins(), findsNWidgets(2));
    });

    testWidgets('um local novo e distante reenquadra o mapa', (tester) async {
      _useDesktopSize(tester);
      const taquara = LatLng(-29.651, -50.781);
      const poa = LatLng(-30.034, -51.217);
      await _pumpMap(tester, <AdminPlaceRecord>[
        _record(
          'taquara',
          'Local taquara',
          taquara.latitude,
          taquara.longitude,
        ),
      ]);
      await _pumpMap(tester, <AdminPlaceRecord>[
        _record(
          'taquara',
          'Local taquara',
          taquara.latitude,
          taquara.longitude,
        ),
        _record('poa', 'Local poa', poa.latitude, poa.longitude),
      ]);

      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      expect(camera.visibleBounds.contains(taquara), isTrue);
      expect(camera.visibleBounds.contains(poa), isTrue);
    });

    testWidgets('sem locais o mapa abre em Taquara', (tester) async {
      _useDesktopSize(tester);
      await _pumpMap(tester, const <AdminPlaceRecord>[]);

      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      expect(
        camera.center.latitude,
        closeTo(adminTaquaraCenter.latitude, 1e-6),
      );
      expect(
        camera.center.longitude,
        closeTo(adminTaquaraCenter.longitude, 1e-6),
      );
      expect(find.text('Nenhum local para exibir no mapa.'), findsOneWidget);
    });

    testWidgets('clicar no pin mostra o nome, que abre o local', (
      tester,
    ) async {
      _useDesktopSize(tester);
      final opened = <String>[];
      await _pumpMap(tester, <AdminPlaceRecord>[
        _record('a', 'Praça A', -29.651, -50.781),
        _record('b', 'Ginásio B', -29.662, -50.792),
      ], onOpenPlace: opened.add);

      await tester.tap(_pinIcon('a'));
      await tester.pumpAndSettle();
      expect(find.text('Praça A'), findsOneWidget);
      expect(find.text('Ginásio B'), findsNothing);

      await tester.tap(find.text('Praça A'));
      expect(opened, <String>['a']);
    });

    testWidgets('erro ao carregar o mapa oferece tentar novamente', (
      tester,
    ) async {
      _useDesktopSize(tester);
      final repository = _FakePlacesRepository();
      await _pumpPage(tester, repository);
      await _openMap(tester);

      repository.allStreams.last.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar o mapa dos locais.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(repository.watchAllCalls, hasLength(2));
    });
  });
}

void _useDesktopSize(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1400, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakePlacesRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminPlacesPage(repository: repository, mapTileLayer: _noTiles),
      ),
    ),
  );
  await tester.pump();
}

// Sem tiles: o teste não tenta baixar o OpenStreetMap.
const Widget _noTiles = SizedBox.shrink();

// O esqueleto tem animação contínua: só `pump` até os dados chegarem.
Future<void> _openMap(WidgetTester tester) async {
  await tester.tap(find.text('Mapa'));
  await tester.pump();
}

Future<void> _pumpMap(
  WidgetTester tester,
  List<AdminPlaceRecord> places, {
  ValueChanged<String>? onOpenPlace,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: <Widget>[
            AdminPlacesMap(
              places: places,
              showNames: false,
              onShowNamesChanged: (_) {},
              onOpenPlace: onOpenPlace ?? (_) {},
              tileLayer: _noTiles,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _pins() => find.descendant(
  of: find.byType(MarkerLayer),
  matching: find.byIcon(Icons.location_pin),
);

Finder _pinIcon(String id) => find.descendant(
  of: find.byKey(ValueKey<String>('place-pin-$id')),
  matching: find.byIcon(Icons.location_pin),
);

Color? _pinColor(WidgetTester tester, String id) =>
    tester.widget<Icon>(_pinIcon(id)).color;

AdminPlaceRecord _record(
  String id,
  String name,
  double latitude,
  double longitude, {
  String status = 'active',
}) => AdminPlaceRecord(
  id: id,
  name: name,
  nameLower: name.toLowerCase(),
  description: 'Espaço esportivo usado nos testes do mapa geral.',
  address: const AdminPlaceAddress(
    street: 'Rua Teste',
    city: 'Taquara',
    cityLower: 'taquara',
    state: 'RS',
  ),
  sports: const <String>['futebol'],
  primarySport: 'futebol',
  coordinates: GeoPoint(latitude, longitude),
  imageUrl: 'https://example.com/$id.jpg',
  status: status,
  createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
  updatedAt: Timestamp.fromMillisecondsSinceEpoch(0),
  isFromCache: false,
);

class _FakePlacesRepository implements AdminPlacesRepository {
  final List<AdminPlacesFilters> watchAllCalls = <AdminPlacesFilters>[];
  final List<StreamController<AdminPlacesCollectionSnapshot>> allStreams =
      <StreamController<AdminPlacesCollectionSnapshot>>[];

  void emitAll(List<AdminPlaceRecord> places) => allStreams.last.add(
    AdminPlacesCollectionSnapshot(places: places, isFromCache: false),
  );

  @override
  Stream<AdminPlacesPageSnapshot> watchPage(
    AdminPlacesFilters filters, {
    AdminPlaceCursor? after,
  }) => StreamController<AdminPlacesPageSnapshot>.broadcast().stream;

  @override
  Stream<AdminPlacesCollectionSnapshot> watchAll(AdminPlacesFilters filters) {
    watchAllCalls.add(filters);
    final stream = StreamController<AdminPlacesCollectionSnapshot>.broadcast();
    allStreams.add(stream);
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
