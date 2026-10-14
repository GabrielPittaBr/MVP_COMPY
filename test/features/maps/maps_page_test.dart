import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/maps/domain/repositories/places_repository.dart';
import 'package:mvp_compy/features/maps/domain/usecases/filter_map_places.dart';
import 'package:mvp_compy/features/maps/presentation/pages/maps_page.dart';
import 'package:mvp_compy/features/maps/presentation/providers/maps_providers.dart';
import 'package:mvp_compy/features/maps/presentation/widgets/place_details_sheet.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';

Map<String, dynamic> _placeDocument({
  required String name,
  required String nameLower,
  required List<String> sports,
  required String primarySport,
  String status = 'active',
}) =>
    <String, dynamic>{
      'name': name,
      'nameLower': nameLower,
      'description': 'Espaço esportivo para atividades da comunidade local.',
      'address': <String, dynamic>{
        'street': 'Rua Central',
        'city': 'Taquara',
        'cityLower': 'taquara',
        'state': 'RS',
      },
      'sports': sports,
      'primarySport': primarySport,
      'coordinates': const GeoPoint(-29.65, -50.78),
      'imageUrl': 'https://example.com/place.jpg',
      'status': status,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026)),
    };

SportPlace _place({
  required String id,
  required String name,
  required String nameLower,
  required List<String> sports,
  required String primarySport,
  String status = 'active',
}) =>
    SportPlace.tryFromFirestore(
      id,
      _placeDocument(
        name: name,
        nameLower: nameLower,
        sports: sports,
        primarySport: primarySport,
        status: status,
      ),
    )!;

void main() {
  group('filterMapPlaces', () {
    final parque = _place(
      id: 'parque',
      name: 'Parque do Trabalhador',
      nameLower: 'parque do trabalhador',
      sports: <String>['futebol', 'corrida'],
      primarySport: 'futebol',
    );
    final quadra = _place(
      id: 'quadra',
      name: 'Quadra Central',
      nameLower: 'quadra central',
      sports: <String>['basquete'],
      primarySport: 'basquete',
    );
    final inactive = _place(
      id: 'inactive',
      name: 'Parque Antigo',
      nameLower: 'parque antigo',
      sports: <String>['futebol'],
      primarySport: 'futebol',
      status: 'inactive',
    );

    test('normaliza busca pt-BR e só encontra prefixo do nome', () {
      final result = filterMapPlaces(
        <SportPlace>[parque, quadra, inactive],
        query: '  PARQUÉ  ',
      );

      expect(result.map((place) => place.id), <String>['parque']);
    });

    test('combina modalidade local e mantém somente locais ativos', () {
      final result = filterMapPlaces(
        <SportPlace>[parque, quadra, inactive],
        sport: Sport.basquete,
      );

      expect(result.map((place) => place.id), <String>['quadra']);
    });

    test('busca sem correspondência produz vazio, não erro', () {
      expect(
        filterMapPlaces(<SportPlace>[parque], query: 'ginásio'),
        isEmpty,
      );
    });
  });

  testWidgets('local inativo informa o estado e desabilita ações novas',
      (tester) async {
    final inactive = _place(
      id: 'old-place',
      name: 'Parque Antigo',
      nameLower: 'parque antigo',
      sports: <String>['futebol'],
      primarySport: 'futebol',
      status: 'inactive',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlaceDetailsSheet(
          place: inactive,
          onCreateEvent: () {},
          onShare: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Local inativo'), findsOneWidget);
    for (final icon in <IconData>[Icons.add, Icons.share_outlined]) {
      final action = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(action.first).onTap, isNull);
    }
  });

  testWidgets('falha do stream exibe erro e opção de tentar novamente',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        placesProvider.overrideWith(
          (ref) => Stream<PlacesStreamResult>.error(
            StateError('Firestore indisponível'),
          ),
        ),
      ],
      child: const MaterialApp(home: MapsPage()),
    ));
    await tester.pump();

    expect(find.text('Não foi possível carregar os locais.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('estado vazio confirmado difere da indicação de offline',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        placesProvider.overrideWith(
          (ref) => Stream<PlacesStreamResult>.value(
            const PlacesStreamResult(
                places: <SportPlace>[], isFromCache: false),
          ),
        ),
      ],
      child: const MaterialApp(home: MapsPage()),
    ));
    await tester.pump();

    expect(
      find.text('Nenhum local ativo disponível no momento.'),
      findsOneWidget,
    );
    expect(find.textContaining('(offline)'), findsNothing);
  });

  testWidgets('dados em cache são exibidos com indicação de offline',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        placesProvider.overrideWith(
          (ref) => Stream<PlacesStreamResult>.value(
            PlacesStreamResult(
              places: <SportPlace>[
                _place(
                  id: 'cached-place',
                  name: 'Parque em cache',
                  nameLower: 'parque em cache',
                  sports: <String>['futebol'],
                  primarySport: 'futebol',
                ),
              ],
              isFromCache: true,
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: MapsPage()),
    ));
    await tester.pump();

    expect(find.text('Exibindo locais salvos neste dispositivo (offline).'),
        findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
  });

  testWidgets('deep link ausente online informa Local não encontrado',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        placesProvider.overrideWith(
          (ref) => Stream<PlacesStreamResult>.value(
            const PlacesStreamResult(
                places: <SportPlace>[], isFromCache: false),
          ),
        ),
        placeByIdProvider.overrideWith(
          (ref, id) async => const PlaceLookupResult(
            place: null,
            isFromCache: false,
          ),
        ),
      ],
      child: const MaterialApp(home: MapsPage(initialPlaceId: 'missing')),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Local não encontrado.'), findsOneWidget);
  });

  testWidgets('pins reagem a novos snapshots sem reconstruir a tela',
      (tester) async {
    final snapshots = StreamController<PlacesStreamResult>();
    addTearDown(snapshots.close);
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        placesProvider.overrideWith((ref) => snapshots.stream),
      ],
      child: const MaterialApp(home: MapsPage()),
    ));
    snapshots.add(PlacesStreamResult(
      places: <SportPlace>[
        _place(
          id: 'parque',
          name: 'Parque do Trabalhador',
          nameLower: 'parque do trabalhador',
          sports: <String>['futebol'],
          primarySport: 'futebol',
        ),
      ],
      isFromCache: false,
    ));
    await tester.pump();

    MarkerLayer markerLayer() => tester.widget<MarkerLayer>(
          find.byType(MarkerLayer),
        );
    expect(markerLayer().markers, hasLength(1));

    snapshots.add(PlacesStreamResult(
      places: <SportPlace>[
        _place(
          id: 'parque',
          name: 'Parque do Trabalhador',
          nameLower: 'parque do trabalhador',
          sports: <String>['futebol'],
          primarySport: 'futebol',
        ),
        _place(
          id: 'quadra',
          name: 'Quadra Central',
          nameLower: 'quadra central',
          sports: <String>['basquete'],
          primarySport: 'basquete',
        ),
      ],
      isFromCache: false,
    ));
    await tester.pump();

    expect(markerLayer().markers, hasLength(2));
  });
}
