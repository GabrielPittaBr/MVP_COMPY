import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../datasources/places_remote_datasource.dart';
import '../../domain/repositories/places_repository.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  PlacesRepositoryImpl(this._remoteDataSource);

  final PlacesRemoteDataSource _remoteDataSource;

  @override
  Stream<PlacesStreamResult> watchActive({Sport? sport}) {
    return _remoteDataSource.watchActive(sport: sport).map((snapshot) {
      final places = snapshot.documents
          .where((doc) => doc.data != null)
          .map((doc) => SportPlace.tryFromFirestore(doc.id, doc.data!))
          .whereType<SportPlace>();
      return PlacesStreamResult(
        places: filterAndSortActivePlaces(places, sport: sport),
        isFromCache: snapshot.isFromCache,
      );
    });
  }

  @override
  Future<PlaceLookupResult> getById(String id) async {
    final snapshot = await _remoteDataSource.getById(id);
    final place = snapshot.exists && snapshot.data != null
        ? SportPlace.tryFromFirestore(id, snapshot.data!)
        : null;
    return PlaceLookupResult(
      place: place,
      isFromCache: snapshot.isFromCache,
    );
  }
}

/// Defesa no limite da aplicação: Firestore já filtra/ordena a query, mas o
/// resultado exposto mantém o contrato mesmo com fixtures/fakes não fiéis.
List<SportPlace> filterAndSortActivePlaces(
  Iterable<SportPlace> places, {
  Sport? sport,
}) {
  final result = places
      .where((place) => place.status == PlaceStatus.active)
      .where((place) => sport == null || place.sports.contains(sport))
      .toList();
  result.sort((a, b) => a.nameLower.compareTo(b.nameLower));
  return List<SportPlace>.unmodifiable(result);
}
