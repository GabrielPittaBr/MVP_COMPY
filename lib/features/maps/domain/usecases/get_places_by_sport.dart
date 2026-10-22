import '../../../../shared/models/sport.dart';
import '../repositories/places_repository.dart';

class GetPlacesBySport {
  const GetPlacesBySport(this._repository);
  final PlacesRepository _repository;

  Stream<PlacesStreamResult> call({Sport? sport}) =>
      _repository.watchActive(sport: sport);
}
