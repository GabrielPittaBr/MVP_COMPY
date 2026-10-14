import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../data/datasources/places_remote_datasource.dart';
import '../../data/repositories/places_repository_impl.dart';
import '../../domain/repositories/places_repository.dart';
import '../../domain/usecases/get_places_by_sport.dart';

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepositoryImpl(
    FirestorePlacesRemoteDataSource(FirebaseFirestore.instance),
  ),
);

final getPlacesBySportProvider = Provider<GetPlacesBySport>(
  (ref) => GetPlacesBySport(ref.watch(placesRepositoryProvider)),
);

/// Filtro atual da tela de mapa (`null` = todos os esportes).
final mapsSportFilterProvider = StateProvider<Sport?>((_) => null);
final mapsSearchQueryProvider = StateProvider<String>((_) => '');

/// Pin selecionado (mostra/esconde o bottom sheet).
///
/// `autoDispose` para a seleção morrer junto com a tela: sem isso, sair
/// do mapa com um local aberto faz a próxima visita já começar com o
/// card na frente.
final selectedPlaceProvider =
    StateProvider.autoDispose<SportPlace?>((_) => null);

final placesProvider = StreamProvider<PlacesStreamResult>((ref) {
  return ref.watch(getPlacesBySportProvider).call();
});

final placeByIdProvider =
    FutureProvider.family<PlaceLookupResult, String>((ref, id) {
  return ref.watch(placesRepositoryProvider).getById(id);
});
