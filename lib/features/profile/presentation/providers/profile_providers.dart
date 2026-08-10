import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/search_users.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? ProfileRemoteDataSource(FirebaseFirestore.instance) : null,
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider)),
);

final getProfileProvider = Provider<GetProfile>(
  (ref) => GetProfile(ref.watch(profileRepositoryProvider)),
);

final searchUsersProvider = Provider<SearchUsers>(
  (ref) => SearchUsers(ref.watch(profileRepositoryProvider)),
);

/// Resultado da busca por handle, com debounce.
///
/// A família é chaveada pelo texto digitado: cada tecla cria um provider novo
/// e descarta o anterior, e o descarte cancela a espera antes de a consulta
/// sair. Só o texto que ficar parado por [_searchDebounce] chega ao Firestore.
final userSearchProvider =
    FutureProvider.autoDispose.family<List<UserSummary>, String>(
  (ref, query) async {
    if (query.trim().replaceFirst('@', '').length < SearchUsers.minPrefixLength) {
      return const <UserSummary>[];
    }

    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(_searchDebounce);
    if (cancelled) return const <UserSummary>[];

    return ref.watch(searchUsersProvider).call(
          query,
          excludeUid: ref.watch(authStateProvider).valueOrNull?.uid,
        );
  },
);

const Duration _searchDebounce = Duration(milliseconds: 350);

final currentProfileProvider = FutureProvider<UserProfile>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) throw Exception('Usuário não autenticado');
  return ref.watch(getProfileProvider).call(uid);
});

/// Identidade pública ([UserSummary]) do usuário logado — usada para
/// registrar participação em eventos e preencher o criador na criação.
final currentUserSummaryProvider = FutureProvider<UserSummary>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile.summary;
});
