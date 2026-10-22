import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';

class PlacesStreamResult {
  const PlacesStreamResult({required this.places, required this.isFromCache});

  final List<SportPlace> places;

  /// `true` indica que o snapshot disponível veio do cache nativo do Firestore.
  final bool isFromCache;

  bool get isEmpty => places.isEmpty;
}

class PlaceLookupResult {
  const PlaceLookupResult({required this.place, required this.isFromCache});

  /// Nulo significa que o documento não existe ou não contém schema válido.
  final SportPlace? place;
  final bool isFromCache;

  bool get exists => place != null;
}

abstract interface class PlacesRepository {
  /// Stream dos locais ativos em ordem alfabética; filtros são feitos no servidor.
  Stream<PlacesStreamResult> watchActive({Sport? sport});

  /// Resolve qualquer status para telas e vínculos históricos.
  Future<PlaceLookupResult> getById(String id);
}
