import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../data/repositories/places_repository_impl.dart';
import '../../domain/repositories/places_repository.dart';
import '../../domain/usecases/get_places_by_sport.dart';

// Sem datasource remoto aqui: o catálogo de locais vive em código
// (ver SportPlace.all), então a cadeia começa direto no repositório.
final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => const PlacesRepositoryImpl(),
);

final getPlacesBySportProvider = Provider<GetPlacesBySport>(
  (ref) => GetPlacesBySport(ref.watch(placesRepositoryProvider)),
);

/// Filtro atual da tela de mapa (`null` = todos os esportes).
final mapsSportFilterProvider = StateProvider<Sport?>((_) => null);

/// Pin selecionado (mostra/esconde o bottom sheet).
///
/// `autoDispose` para a seleção morrer junto com a tela: sem isso, sair
/// do mapa com um local aberto faz a próxima visita já começar com o
/// card na frente.
final selectedPlaceProvider =
    StateProvider.autoDispose<SportPlace?>((_) => null);

final placesProvider = FutureProvider<List<SportPlace>>((ref) {
  final filter = ref.watch(mapsSportFilterProvider);
  return ref.watch(getPlacesBySportProvider).call(sport: filter);
});
