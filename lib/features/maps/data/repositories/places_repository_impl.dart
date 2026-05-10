import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/sport.dart';
import '../../domain/entities/sport_place.dart';
import '../../domain/repositories/places_repository.dart';
import '../datasources/mock_places.dart';
import '../datasources/places_remote_datasource.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  PlacesRepositoryImpl(this._remote);
  // ignore: unused_field
  final PlacesRemoteDataSource _remote;

  @override
  Future<List<SportPlace>> getAll() async {
    if (!kUseFirebaseRepos) return MockPlaces.all;
    // TODO(integração): mapear QuerySnapshot -> List<SportPlace>.
    return <SportPlace>[];
  }

  @override
  Future<List<SportPlace>> getBySport(Sport sport) async {
    final all = await getAll();
    return all.where((p) => p.sport == sport).toList();
  }
}
