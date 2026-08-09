import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../repositories/places_repository.dart';

class GetPlacesBySport {
  const GetPlacesBySport(this._repository);
  final PlacesRepository _repository;

  /// Retorna todos os locais quando [sport] é nulo, caso contrário filtra
  /// pelos que permitem a modalidade.
  Future<List<SportPlace>> call({Sport? sport}) {
    return sport == null ? _repository.getAll() : _repository.getBySport(sport);
  }
}
