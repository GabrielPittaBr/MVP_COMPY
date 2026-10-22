import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/event_place_snapshot.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

void main() {
  const address = PlaceAddress(
    street: 'Rua Central',
    number: '10',
    city: 'Taquara',
    cityLower: 'taquara',
    state: 'RS',
  );
  const place = SportPlace(
    id: 'place-1',
    name: 'Quadra Central',
    nameLower: 'quadra central',
    description: 'Espaço esportivo comunitário para atividades locais.',
    address: address,
    coordinates: LatLng(-29.65, -50.78),
    sports: <Sport>[Sport.futebol],
    primarySport: Sport.futebol,
    status: PlaceStatus.active,
    imageUrl: 'https://example.com/place.jpg',
  );

  Event event({String? placeId, EventPlaceSnapshot? placeSnapshot}) => Event(
        id: 'event-1',
        title: 'Pelada de quinta',
        sport: Sport.futebol,
        location: 'Quadra Central, Taquara',
        coordinates: place.coordinates,
        dateTime: DateTime.utc(2026, 9, 30, 19),
        skillLevel: SkillLevel.todos,
        totalSpots: 8,
        remainingSpots: 7,
        bannerUrl: '',
        creator: const UserSummary(
          id: 'creator',
          name: 'Criador',
          handle: '@criador',
          avatarUrl: '',
        ),
        placeId: placeId,
        placeSnapshot: placeSnapshot,
      );

  test('serializa o contrato novo com coordenadas e geohash no topo', () {
    final snapshot = EventPlaceSnapshot.fromPlace(place);
    final data = event(placeId: place.id, placeSnapshot: snapshot).toMap();

    expect(data['placeId'], 'place-1');
    expect(data['placeSnapshot'], <String, dynamic>{
      'name': 'Quadra Central',
      'address': address.toMap(),
      'coordinates': const GeoPoint(-29.65, -50.78),
    });
    expect(data['coordinates'], const GeoPoint(-29.65, -50.78));
    expect(data['geohash'], isA<String>());
    expect(data['location'], 'Quadra Central, Taquara');
  });

  test('lê snapshot histórico sem depender do estado atual do local', () {
    final original = event(
      placeId: place.id,
      placeSnapshot: EventPlaceSnapshot.fromPlace(place),
    );
    final restored = Event.fromMap(original.id, <String, dynamic>{
      ...original.toMap(),
      'dateTime': Timestamp.fromDate(original.dateTime),
    });

    expect(restored.placeId, 'place-1');
    expect(restored.placeSnapshot, EventPlaceSnapshot.fromPlace(place));
    expect(restored.coordinates, place.coordinates);
  });

  test('evento legado continua legível sem inventar placeId ou snapshot', () {
    final legacy = Event.fromMap('legacy-event', <String, dynamic>{
      'title': 'Evento legado',
      'sport': 'futebol',
      'location': 'Parque, Taquara',
      'coordinates': const GeoPoint(-29.65, -50.78),
      'dateTime': Timestamp.fromDate(DateTime.utc(2026, 9, 30, 19)),
      'totalSpots': 8,
      'remainingSpots': 7,
      'creator': const <String, dynamic>{'id': 'creator'},
    });

    expect(legacy.placeId, isNull);
    expect(legacy.placeSnapshot, isNull);
    expect(legacy.location, 'Parque, Taquara');
    expect(legacy.coordinates, place.coordinates);
  });

  test('serialização rejeita contrato parcial de local', () {
    expect(
      () => event(placeId: place.id).toMap(),
      throwsA(isA<StateError>()),
    );
  });
}
