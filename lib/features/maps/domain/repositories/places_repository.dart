import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';

abstract interface class PlacesRepository {
  Future<List<SportPlace>> getAll();
  Future<List<SportPlace>> getBySport(Sport sport);
}
