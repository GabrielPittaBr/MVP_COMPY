import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/sport.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/entities/sport_category.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_categories.dart';
import '../../domain/usecases/get_nearby_events.dart';

/// Providers da feature Home. Toda a árvore de DI parte daqui — substituir
/// o `homeRepositoryProvider` em testes mocka todo o fluxo.
final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? HomeRemoteDataSource(FirebaseFirestore.instance) : null,
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepositoryImpl(ref.watch(homeRemoteDataSourceProvider)),
);

final getCategoriesProvider = Provider<GetCategories>(
  (ref) => GetCategories(ref.watch(homeRepositoryProvider)),
);

final getNearbyEventsProvider = Provider<GetNearbyEvents>(
  (ref) => GetNearbyEvents(ref.watch(homeRepositoryProvider)),
);

/// Categorias do carrossel, seguindo os esportes favoritos do perfil.
///
/// Lê o perfil **sem esperar**: enquanto ele não chega, o carrossel mostra o
/// trio padrão e troca sozinho quando os favoritos aparecem. Segurar a Home
/// em branco por causa de uma faixa de categorias seria trocar um problema
/// pequeno por um grande — e quem pulou o onboarding nunca teria favoritos
/// para esperar.
final categoriesProvider = Provider<List<SportCategory>>((ref) {
  final List<Sport> favoriteSports =
      ref.watch(currentProfileProvider).valueOrNull?.favoriteSports ??
          const <Sport>[];
  return ref.watch(getCategoriesProvider).call(favoriteSports: favoriteSports);
});

/// Eventos próximos à posição real do usuário (RF03). Aguarda a
/// resolução da localização (com fallback para o centro de Taquara —
/// ver [userPositionProvider]) e então observa a consulta geográfica.
final nearbyEventsProvider = StreamProvider<List<Event>>((ref) async* {
  final position = await ref.watch(userPositionProvider.future);
  yield* ref.watch(getNearbyEventsProvider).call(position);
});

/// Nome de exibição do usuário logado, vindo do AuthUser autenticado.
final greetingNameProvider = Provider<String>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  return authUser?.displayName ?? '';
});
