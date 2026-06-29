import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? ProfileRemoteDataSource(FirebaseFirestore.instance) : null,
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider)),
);

final getProfileProvider = Provider<GetProfile>(
  (ref) => GetProfile(ref.watch(profileRepositoryProvider)),
);

final currentProfileProvider = FutureProvider<UserProfile>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) throw Exception('Usuário não autenticado');
  return ref.watch(getProfileProvider).call(uid);
});
