import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/features/chat/domain/entities/message.dart';
import 'package:mvp_compy/features/chat/presentation/widgets/place_message_card.dart';
import 'package:mvp_compy/features/maps/domain/repositories/places_repository.dart';
import 'package:mvp_compy/features/maps/presentation/providers/maps_providers.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';

void main() {
  const placeId = 'place-1';
  const snapshot = PlaceMessageSnapshot(
    name: 'Nome histórico',
    imageUrl: 'https://example.com/historico.jpg',
    primarySport: Sport.futebol,
  );

  Widget app(PlaceLookupResult result, {PlaceMessageSnapshot? fallback}) {
    return ProviderScope(
      overrides: [
        placeByIdProvider(placeId).overrideWith((ref) async => result),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlaceMessageCard(
              placeId: placeId,
              isMine: false,
              snapshot: fallback,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('usa o documento atual e indica quando o local está inativo',
      (tester) async {
    const current = SportPlace(
      id: placeId,
      name: 'Nome atual',
      nameLower: 'nome atual',
      description: 'Descrição suficientemente longa para o fixture de teste.',
      address: PlaceAddress(
        street: 'Rua Atual',
        city: 'Taquara',
        cityLower: 'taquara',
        state: 'RS',
      ),
      coordinates: LatLng(-29.65, -50.78),
      sports: <Sport>[Sport.basquete],
      primarySport: Sport.basquete,
      status: PlaceStatus.inactive,
      imageUrl: 'https://example.com/atual.jpg',
    );

    await tester.pumpWidget(
      app(const PlaceLookupResult(place: current, isFromCache: false),
          fallback: snapshot),
    );
    await tester.pump();

    expect(find.text('Nome atual'), findsOneWidget);
    expect(find.text('Nome histórico'), findsNothing);
    expect(find.text('Basquete'), findsOneWidget);
    expect(find.text('Local inativo'), findsOneWidget);
    expect(find.text('Rua Atual · Taquara - RS'), findsOneWidget);
  });

  testWidgets('usa snapshot quando a leitura atual falha', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeByIdProvider(placeId).overrideWith(
            (ref) async => throw StateError('sem conexão'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlaceMessageCard(
                placeId: placeId,
                isMine: false,
                snapshot: snapshot,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nome histórico'), findsOneWidget);
    expect(find.text('Futebol'), findsOneWidget);
  });

  testWidgets('local legado não resolvido usa fallback genérico',
      (tester) async {
    await tester.pumpWidget(
      app(const PlaceLookupResult(place: null, isFromCache: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Encaminhou um local...'), findsOneWidget);
  });
}
