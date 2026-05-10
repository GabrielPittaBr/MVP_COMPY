import '../../../../shared/models/sport.dart';
import '../entities/sport_place.dart';
import '../repositories/places_repository.dart';

class GetPlacesBySport {
  const GetPlacesBySport(this._repository);
  final PlacesRepository _repository;

  /// Retorna todos os locais quando [sport] é nulo, caso contrário filtra.
  Future<List<SportPlace>> call({Sport? sport}) {
    return sport == null ? _repository.getAll() : _repository.getBySport(sport);
  }
}
