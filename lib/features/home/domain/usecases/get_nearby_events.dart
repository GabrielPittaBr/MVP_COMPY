import 'package:latlong2/latlong.dart';

import '../../../../shared/models/event.dart';
import '../repositories/home_repository.dart';

/// Usecase que expõe a lista de eventos próximos à posição do usuário.
///
/// Hoje é só um repassador, mas mantemos a camada para acomodar futuras
/// regras de matchmaking (RF03 — proximidade + nível + interesses) sem
/// vazá-las para a UI.
class GetNearbyEvents {
  const GetNearbyEvents(this._repository);
  final HomeRepository _repository;

  Stream<List<Event>> call(LatLng center) =>
      _repository.watchNearbyEvents(center);
}
