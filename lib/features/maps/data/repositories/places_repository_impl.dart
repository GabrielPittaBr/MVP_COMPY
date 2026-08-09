import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../domain/repositories/places_repository.dart';

/// Locais **não** vêm do Firestore: o catálogo é curado pela equipe
/// (RN-04), é pequeno e muda raramente, então vive em código —
/// [SportPlace.all] é a única fonte. Por isso este repositório ignora
/// `kUseFirebaseRepos`: antes ele devolvia lista vazia com Firebase
/// ligado e o mapa ficava sem nenhum pin.
class PlacesRepositoryImpl implements PlacesRepository {
  const PlacesRepositoryImpl();

  @override
  Future<List<SportPlace>> getAll() async => SportPlace.all;

  @override
  Future<List<SportPlace>> getBySport(Sport sport) async {
    final all = await getAll();
    return all.where((p) => p.allowedSports.contains(sport)).toList();
  }
}
