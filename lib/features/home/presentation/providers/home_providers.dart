import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/event.dart';
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

final categoriesProvider = Provider<List<SportCategory>>(
  (ref) => ref.watch(getCategoriesProvider).call(),
);

final nearbyEventsProvider = StreamProvider<List<Event>>(
  (ref) => ref.watch(getNearbyEventsProvider).call(),
);

/// Nome de exibição do usuário logado. Hoje fixo no mock; quando o login
/// estiver implementado, plugar via AuthService.
final greetingNameProvider = Provider<String>((ref) => 'João Souza');
