import 'dart:typed_data';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_flags.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/mock_profile.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);
  final ProfileRemoteDataSource? _remote;

  static bool _validPublicUid(String uid) =>
      uid.isNotEmpty &&
      uid.trim() == uid &&
      uid != '.' &&
      uid != '..' &&
      !uid.contains('/') &&
      !uid.contains('\u0000');

  @override
  Future<UserProfile> getCurrentProfile(String uid) async {
    if (!kUseFirebaseRepos || _remote == null) return MockProfile.current;

    final doc = await _remote.fetchById(uid);
    if (!doc.exists) throw StateError('Perfil do usuário não encontrado.');

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
      gallery: const [],
    );
  }

  @override
  Future<UserProfile?> getPublicProfile(String uid) async {
    if (!_validPublicUid(uid)) {
      return null;
    }
    if (!kUseFirebaseRepos || _remote == null) {
      return MockProfile.publicById(uid);
    }
    final doc = await _remote.fetchById(uid);
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return UserProfile(
      summary: UserSummary(
        id: doc.id,
        name: (data['name'] as String?) ?? '',
        handle: (data['handle'] as String?) ?? '',
        avatarUrl: (data['avatarUrl'] as String?) ?? '',
      ),
      bio: (data['bio'] as String?) ?? '',
      favoriteSports: Sport.parseList(data[Sport.favoriteSportsField]),
      badges: const [],
      friends: const [],
      gallery: const [],
    );
  }

  @override
  Stream<UserSummary?> watchPublicSummary(String uid) {
    if (!_validPublicUid(uid)) return Stream<UserSummary?>.value(null);
    if (!kUseFirebaseRepos || _remote == null) {
      return Stream<UserSummary?>.value(MockProfile.publicById(uid)?.summary);
    }
    return _remote.watchById(uid).map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return UserSummary(
        id: doc.id,
        name: (data['name'] as String?) ?? '',
        handle: (data['handle'] as String?) ?? '',
        avatarUrl: (data['avatarUrl'] as String?) ?? '',
      );
    });
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
  Future<void> updateDetails(String uid,
      {required String name,
      required String bio,
      required bool nameChanged}) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty || cleanedName.length > 60 || bio.length > 160) {
      throw ArgumentError('Nome ou biografia inválidos.');
    }
    if (!kUseFirebaseRepos || _remote == null) {
      if (uid != MockProfile.current.summary.id) {
        throw StateError('Perfil não pertence ao usuário atual.');
      }
      MockProfile.nameOverride = cleanedName;
      MockProfile.bioOverride = bio;
      return;
    }
    await _remote.updatePublicDetails(uid, cleanedName, bio);
    if (nameChanged) {
      // Firestore e Auth não compartilham transação. Preserve a informação de
      // que o perfil já foi gravado para a tela oferecer uma nova tentativa.
      try {
        await _remote.updateAuthDisplayName(uid, cleanedName);
      } catch (error, stack) {
        Error.throwWithStackTrace(ProfileAuthSyncException(error), stack);
      }
    }
  }

  @override
  Future<void> updateAvatar(
    String uid, {
    required String name,
    Uint8List? jpeg,
  }) async {
    // ponytail: o modo mock não guarda foto (não há Storage), então trocar
    // ou remover não tem efeito sem Firebase. Guardar os bytes num override
    // do MockProfile se alguém precisar testar a tela assim.
    if (!kUseFirebaseRepos || _remote == null) return;

    final String avatarUrl = jpeg == null
        ? AppAssets.avatar(name)
        : await _remote.uploadAvatar(uid, jpeg);
    await _remote.updateAvatarUrl(uid, avatarUrl);
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

  @override
  Future<List<UserSummary>> searchByName(
    String namePrefix, {
    String? excludeUid,
    int limit = 20,
  }) async {
    final prefix = TextNormalizer.normalize(namePrefix);
    if (prefix.isEmpty) return const <UserSummary>[];

    if (!kUseFirebaseRepos || _remote == null) {
      return MockProfile.searchable
          .where(
            (user) =>
                user.id != excludeUid &&
                TextNormalizer.normalize(user.name).startsWith(prefix),
          )
          .take(limit)
          .toList();
    }

    final snapshot = await _remote.searchByNamePrefix(prefix, limit: limit);
    return snapshot.docs
        .where((doc) => doc.id != excludeUid)
        .map(
          (doc) => UserSummary.fromMap(<String, dynamic>{
            ...doc.data(),
            'id': doc.id,
          }),
        )
        .toList();
  }
}
