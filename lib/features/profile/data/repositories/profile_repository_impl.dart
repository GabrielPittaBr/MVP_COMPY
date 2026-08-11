import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/rating_summary.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/mock_profile.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);
  final ProfileRemoteDataSource? _remote;

  @override
  Future<UserProfile> getCurrentProfile(String uid) async {
    if (!kUseFirebaseRepos || _remote == null) return MockProfile.current;

    final doc = await _remote.fetchById(uid);
    if (!doc.exists) return MockProfile.current;

    final data = doc.data()!;
    final summary = UserSummary(
      id: uid,
      name: (data['name'] as String?) ?? '',
      handle: (data['handle'] as String?) ?? '',
      avatarUrl: (data['avatarUrl'] as String?) ?? '',
    );

    return UserProfile(
      summary: summary,
      bio: (data['bio'] as String?) ?? '',
      favoriteSports: Sport.parseList(data[Sport.favoriteSportsField]),
      badges: const [],
      friends: const [],
      rating: const RatingSummary(average: 0, count: 0, breakdown: {}),
      gallery: const [],
    );
  }

  @override
  Future<void> updateFavoriteSports(String uid, List<Sport> sports) async {
    if (!kUseFirebaseRepos || _remote == null) {
      MockProfile.favoriteSportsOverride = List<Sport>.unmodifiable(sports);
      return;
    }
    await _remote.updateFavoriteSports(uid, Sport.toStorage(sports));
  }

  @override
  Future<List<UserSummary>> searchByHandle(
    String handlePrefix, {
    String? excludeUid,
    int limit = 20,
  }) async {
    final prefix = handlePrefix.trim().toLowerCase().replaceFirst('@', '');
    if (prefix.isEmpty) return const <UserSummary>[];

    if (!kUseFirebaseRepos || _remote == null) {
      return MockProfile.searchable
          .where((u) =>
              u.id != excludeUid &&
              u.handle.toLowerCase().startsWith('@$prefix'))
          .take(limit)
          .toList();
    }

    final snapshot = await _remote.searchByHandlePrefix(prefix, limit: limit);
    return snapshot.docs
        .where((doc) => doc.id != excludeUid)
        .map((doc) => UserSummary.fromMap(<String, dynamic>{
              ...doc.data(),
              // O perfil grava `id`, mas quem manda é o doc id: é ele que a
              // conversa vai usar como membro.
              'id': doc.id,
            }))
        .toList();
  }
}
