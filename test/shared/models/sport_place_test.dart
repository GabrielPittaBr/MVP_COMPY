import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('SportPlace', () {
    const place = SportPlace(
      id: 'fixture-place',
      name: 'Local de teste',
      nameLower: 'local de teste',
      description: 'Local esportivo usado somente como fixture de teste.',
      address: PlaceAddress(
        street: 'Rua de Teste',
        city: 'Taquara',
        cityLower: 'taquara',
        state: 'RS',
      ),
      coordinates: LatLng(-29.65, -50.78),
      sports: <Sport>[Sport.futebol],
      primarySport: Sport.futebol,
      status: PlaceStatus.active,
      imageUrl: 'https://example.test/place.jpg',
    );

    test('alterar status preserva identidade e contrato do local', () {
      final inactive = place.copyWithStatus(PlaceStatus.inactive);

      expect(inactive.id, place.id);
      expect(inactive.status, PlaceStatus.inactive);
      expect(inactive.name, place.name);
      expect(inactive.coordinates, place.coordinates);
      expect(inactive.sports, place.sports);
    });
  });
}
