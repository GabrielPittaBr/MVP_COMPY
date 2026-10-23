import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/home/presentation/providers/home_providers.dart';
import 'package:mvp_compy/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:mvp_compy/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:mvp_compy/features/profile/domain/entities/user_profile.dart';
import 'package:mvp_compy/features/profile/domain/repositories/profile_repository.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

class _Remote implements ProfileRemoteDataSource {
  final calls = <String>[];
  bool failAuth = false;

  @override
  Future<void> updatePublicDetails(String uid, String name, String bio) async {
    calls.add('firestore:$uid:$name:$bio');
  }

  @override
  Future<void> updateAuthDisplayName(String uid, String name) async {
    calls.add('auth:$uid:$name');
    if (failAuth) throw StateError('auth indisponivel');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileRepository {
  String name = 'Ana';
  String bio = '';

  UserProfile get profile => UserProfile(
        summary:
            UserSummary(id: 'uid', name: name, handle: '@ana', avatarUrl: ''),
        bio: bio,
        favoriteSports: const [],
        badges: const [],
        friends: const [],
        gallery: const [],
      );

  @override
  Future<UserProfile> getCurrentProfile(String uid) async => profile;

  @override
  Future<UserProfile?> getPublicProfile(String uid) async => profile;

  @override
  Future<void> updateDetails(String uid,
      {required String name, required String bio}) async {
    this.name = name;
    this.bio = bio;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('nome e bio sao gravados antes da sincronizacao do Auth', () async {
    final remote = _Remote();
    final repo = ProfileRepositoryImpl(remote);
    await repo.updateDetails('uid', name: '  João Silva  ', bio: 'Vôlei');
    expect(remote.calls,
        ['firestore:uid:João Silva:Vôlei', 'auth:uid:João Silva']);
  });

  test('falha do Auth nao vira sucesso e tentativa seguinte conclui', () async {
    final remote = _Remote()..failAuth = true;
    final repo = ProfileRepositoryImpl(remote);
    await expectLater(
        repo.updateDetails('uid', name: 'Maria', bio: ''), throwsStateError);
    remote.failAuth = false;
    await repo.updateDetails('uid', name: 'Maria', bio: '');
    expect(remote.calls, [
      'firestore:uid:Maria:',
      'auth:uid:Maria',
      'firestore:uid:Maria:',
      'auth:uid:Maria',
    ]);
  });

  test('nome vazio e limites invalidos sao recusados antes de gravar',
      () async {
    final remote = _Remote();
    final repo = ProfileRepositoryImpl(remote);
    await expectLater(
        repo.updateDetails('uid', name: '   ', bio: ''), throwsArgumentError);
    await expectLater(repo.updateDetails('uid', name: 'a' * 61, bio: ''),
        throwsArgumentError);
    await expectLater(repo.updateDetails('uid', name: 'Ana', bio: 'a' * 161),
        throwsArgumentError);
    expect(remote.calls, isEmpty);
  });

  test('salvamento atualiza perfil proprio, publico e saudacao da Home',
      () async {
    final profiles = _Profiles();
    final container = ProviderContainer(overrides: [
      profileRepositoryProvider.overrideWith((_) => profiles),
      authStateProvider.overrideWith((_) => Stream.value(const AuthUser(
            uid: 'uid',
            email: 'privado@example.com',
            displayName: 'Ana',
            hasUsername: true,
            hasFavoriteSports: true,
          ))),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    expect((await container.read(currentProfileProvider.future)).summary.name,
        'Ana');
    expect(
        (await container.read(publicProfileProvider('uid').future))!.bio, '');
    await container.read(profileDetailsControllerProvider.future);
    expect(
        await container
            .read(profileDetailsControllerProvider.notifier)
            .save('uid', name: 'Ana Silva', bio: 'Basquete'),
        isTrue);
    expect((await container.read(currentProfileProvider.future)).summary.name,
        'Ana Silva');
    expect((await container.read(publicProfileProvider('uid').future))!.bio,
        'Basquete');
    expect(container.read(greetingNameProvider), 'Ana Silva');
  });
}
