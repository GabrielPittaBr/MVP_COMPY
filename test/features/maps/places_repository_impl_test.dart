import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/maps/data/datasources/places_remote_datasource.dart';
import 'package:mvp_compy/features/maps/data/repositories/places_repository_impl.dart';
import 'package:mvp_compy/features/maps/domain/repositories/places_repository.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';

Map<String, dynamic> placeDocument({
  String name = 'Parque do Trabalhador',
  String nameLower = 'parque do trabalhador',
  String imageUrl = 'https://example.com/place.jpg',
  Object? coordinates,
  Object? sports = const <String>['futebol', 'corrida'],
  String primarySport = 'futebol',
  String status = 'active',
}) =>
    <String, dynamic>{
      'name': name,
      'nameLower': nameLower,
      'description': 'Parque público com campo, quadras e pista esportiva.',
      'address': <String, dynamic>{
        'street': 'Rua do Parque',
        'number': '100',
        'city': 'Taquara',
        'cityLower': 'taquara',
        'state': 'RS',
        'postalCode': '95600000',
      },
      'sports': sports,
      'primarySport': primarySport,
      'coordinates': coordinates ?? const GeoPoint(-29.65, -50.78),
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
    };

void main() {
  group('SportPlace Firestore contract', () {
    test('parses schema, explicit primary sport and server timestamps', () {
      final place = SportPlace.tryFromFirestore('place-1', placeDocument());

      expect(place, isNotNull);
      expect(place!.id, 'place-1');
      expect(place.nameLower, 'parque do trabalhador');
      expect(place.address.cityLower, 'taquara');
      expect(place.address.formatted, 'Rua do Parque, 100 · Taquara - RS');
      expect(place.sports, <Sport>[Sport.futebol, Sport.corrida]);
      expect(place.primarySport, Sport.futebol);
      expect(place.status, PlaceStatus.active);
      expect(place.coordinates.latitude, closeTo(-29.65, 0.00001));
      expect(
        place.createdAt!.isAtSameMomentAs(DateTime.utc(2026, 1, 1)),
        isTrue,
      );
      expect(
        place.updatedAt!.isAtSameMomentAs(DateTime.utc(2026, 1, 2)),
        isTrue,
      );
    });

    test('normaliza campos opcionais vazios sem fabricar endereço', () {
      final data = placeDocument();
      data['address'] = <String, dynamic>{
        'street': 'Rua Central',
        'city': 'São João',
        'cityLower': 'sao joao',
        'state': 'RS',
        'number': ' ',
      };
      final place = SportPlace.tryFromFirestore('place-1', data);

      expect(place, isNotNull);
      expect(place!.address.number, isNull);
      expect(place.address.formatted, 'Rua Central · São João - RS');
    });

    test('ignora documentos incompletos ou incompatíveis sem derrubar leitura',
        () {
      final missingField = placeDocument()..remove('updatedAt');
      final unknownSport = placeDocument(sports: <String>['futebol', 'rugby']);
      final duplicateSport =
          placeDocument(sports: <String>['futebol', 'futebol']);
      final mismatchedPrimary = placeDocument(primarySport: 'basquete');
      final invalidNormalizedName = placeDocument(nameLower: 'Parque');
      final invalidImage =
          placeDocument(imageUrl: 'http://example.com/place.jpg');
      final wrongCoordinates = placeDocument(coordinates: '(-29.65,-50.78)');
      final inactiveRatings = placeDocument()..['rating'] = 5.0;

      for (final data in <Map<String, dynamic>>[
        missingField,
        unknownSport,
        duplicateSport,
        mismatchedPrimary,
        invalidNormalizedName,
        invalidImage,
        wrongCoordinates,
        inactiveRatings,
      ]) {
        expect(
          SportPlace.tryFromFirestore('bad', data),
          isNull,
          reason: 'malformed document must be ignored safely: $data',
        );
      }
    });

    test('schema de PlaceAddress exige normalização e UF em maiúsculas', () {
      final data = placeDocument();
      data['address'] = <String, dynamic>{
        'street': 'Rua A',
        'city': 'São João',
        'cityLower': 'são joão',
        'state': 'rs',
      };
      expect(SportPlace.tryFromFirestore('bad', data), isNull);
    });

    test('preserva local inativo para resolução histórica por ID', () {
      final inactive = SportPlace.tryFromFirestore(
        'place-inactive',
        placeDocument(status: 'inactive'),
      );

      expect(inactive, isNotNull);
      expect(inactive!.id, 'place-inactive');
      expect(inactive.status, PlaceStatus.inactive);
    });
  });

  group('filterAndSortActivePlaces', () {
    test('mantém somente ativos e ordena por nameLower com filtro opcional',
        () {
      final parque = SportPlace.tryFromFirestore('parque', placeDocument())!;
      final quadra = SportPlace.tryFromFirestore(
        'quadra',
        placeDocument(
          name: 'Quadra Central',
          nameLower: 'quadra central',
          sports: <String>['basquete'],
          primarySport: 'basquete',
        ),
      )!;
      final inactive = SportPlace.tryFromFirestore(
        'inactive',
        placeDocument(
          name: 'Arena Inativa',
          nameLower: 'arena inativa',
          status: 'inactive',
        ),
      )!;

      final all = filterAndSortActivePlaces(<SportPlace>[
        quadra,
        inactive,
        parque,
      ]);
      final basketball = filterAndSortActivePlaces(
        <SportPlace>[quadra, parque, inactive],
        sport: Sport.basquete,
      );

      expect(all.map((place) => place.id), <String>['parque', 'quadra']);
      expect(basketball.map((place) => place.id), <String>['quadra']);
    });
  });

  group('PlacesStreamResult / PlaceLookupResult', () {
    test('preserva vazio confirmado versus dados em cache', () {
      const cachedEmpty = PlacesStreamResult(
        places: <SportPlace>[],
        isFromCache: true,
      );
      const confirmedEmpty = PlacesStreamResult(
        places: <SportPlace>[],
        isFromCache: false,
      );

      expect(cachedEmpty.isEmpty, isTrue);
      expect(cachedEmpty.isFromCache, isTrue);
      expect(confirmedEmpty.isEmpty, isTrue);
      expect(confirmedEmpty.isFromCache, isFalse);
    });

    test('representa resolução histórica ausente ou encontrada no cache', () {
      const missing = PlaceLookupResult(place: null, isFromCache: false);
      final inactive = SportPlace.tryFromFirestore(
        'inactive',
        placeDocument(status: 'inactive'),
      )!;
      final cached = PlaceLookupResult(place: inactive, isFromCache: true);

      expect(missing.exists, isFalse);
      expect(cached.exists, isTrue);
      expect(cached.place!.status, PlaceStatus.inactive);
      expect(cached.isFromCache, isTrue);
    });
  });
  group('PlacesRepositoryImpl', () {
    test('aplica filtro, ordenação, status e metadata recebidos da fonte',
        () async {
      final remote = _FakePlacesRemoteDataSource(
        activeSnapshot: PlacesDocumentsSnapshot(
          isFromCache: true,
          documents: <PlaceDocumentSnapshot>[
            PlaceDocumentSnapshot(
              id: 'quadra',
              data: placeDocument(
                name: 'Quadra Central',
                nameLower: 'quadra central',
                sports: <String>['basquete'],
                primarySport: 'basquete',
              ),
              isFromCache: true,
            ),
            PlaceDocumentSnapshot(
              id: 'parque',
              data: placeDocument(),
              isFromCache: true,
            ),
            PlaceDocumentSnapshot(
              id: 'inactive',
              data: placeDocument(status: 'inactive'),
              isFromCache: true,
            ),
            const PlaceDocumentSnapshot(
              id: 'malformed',
              data: <String, dynamic>{'name': 'inválido'},
              isFromCache: true,
            ),
          ],
        ),
      );
      final repository = PlacesRepositoryImpl(remote);

      final result = await repository.watchActive(sport: Sport.futebol).first;

      expect(remote.requestedSport, Sport.futebol);
      expect(result.places.map((place) => place.id), <String>['parque']);
      expect(result.isFromCache, isTrue);
    });

    test('resolve por ID retorna local inativo e metadado de origem', () async {
      final remote = _FakePlacesRemoteDataSource(
        activeSnapshot: const PlacesDocumentsSnapshot(
          documents: <PlaceDocumentSnapshot>[],
          isFromCache: false,
        ),
        placeById: PlaceDocumentSnapshot(
          id: 'inactive',
          data: placeDocument(status: 'inactive'),
          isFromCache: false,
        ),
      );
      final repository = PlacesRepositoryImpl(remote);

      final result = await repository.getById('inactive');

      expect(remote.requestedId, 'inactive');
      expect(result.place!.status, PlaceStatus.inactive);
      expect(result.isFromCache, isFalse);
    });

    test('propaga erro do stream em vez de convertê-lo em lista vazia',
        () async {
      final remote = _FakePlacesRemoteDataSource(
        activeSnapshot: const PlacesDocumentsSnapshot(
          documents: <PlaceDocumentSnapshot>[],
          isFromCache: false,
        ),
        streamError: StateError('Firestore indisponível'),
      );
      final repository = PlacesRepositoryImpl(remote);

      await expectLater(
        repository.watchActive(),
        emitsError(isA<StateError>()),
      );
    });
  });
}

class _FakePlacesRemoteDataSource implements PlacesRemoteDataSource {
  _FakePlacesRemoteDataSource({
    required this.activeSnapshot,
    this.placeById = const PlaceDocumentSnapshot(
      id: '',
      data: null,
      isFromCache: false,
    ),
    this.streamError,
  });

  final PlacesDocumentsSnapshot activeSnapshot;
  PlaceDocumentSnapshot placeById;
  final Object? streamError;
  Sport? requestedSport;
  String? requestedId;

  @override
  Stream<PlacesDocumentsSnapshot> watchActive({Sport? sport}) {
    requestedSport = sport;
    if (streamError != null) {
      return Stream<PlacesDocumentsSnapshot>.error(streamError!);
    }
    return Stream<PlacesDocumentsSnapshot>.value(activeSnapshot);
  }

  @override
  Future<PlaceDocumentSnapshot> getById(String id) async {
    requestedId = id;
    return placeById;
  }
}
