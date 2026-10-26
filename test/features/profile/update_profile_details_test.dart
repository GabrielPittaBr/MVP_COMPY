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
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

class _Remote implements ProfileRemoteDataSource {
  final calls = <String>[];
  bool failAuth = false;
  bool failFirestore = false;

  @override
  Future<void> updatePublicDetails(String uid, String name, String bio) async {
    calls.add('firestore:$uid:$name:$bio');
    if (failFirestore) throw StateError('firestore indisponivel');
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
        summary: UserSummary(
            id: 'uid',
            name: name,
            handle: '@ana',
            avatarUrl: 'https://example.com/ana.jpg'),
        bio: bio,
        favoriteSports: const [Sport.volei],
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
      {required String name,
      required String bio,
      required bool nameChanged}) async {
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
    await repo.updateDetails('uid',
        name: '  João Silva  ', bio: 'Vôlei', nameChanged: true);
    expect(remote.calls,
        ['firestore:uid:João Silva:Vôlei', 'auth:uid:João Silva']);
  });

  test('somente bio grava no Firestore sem depender do Auth', () async {
    final remote = _Remote()..failAuth = true;
    final repo = ProfileRepositoryImpl(remote);
    await repo.updateDetails('uid',
        name: 'Ana', bio: 'Nova biografia', nameChanged: false);
    expect(remote.calls, ['firestore:uid:Ana:Nova biografia']);
  });

  test('somente nome grava e sincroniza o Auth', () async {
    final remote = _Remote();
    final repo = ProfileRepositoryImpl(remote);
    await repo.updateDetails('uid',
        name: 'Maria', bio: 'Bio anterior', nameChanged: true);
    expect(
        remote.calls, ['firestore:uid:Maria:Bio anterior', 'auth:uid:Maria']);
  });

  test('falha do Firestore impede Auth e nova tentativa pode concluir',
      () async {
    final remote = _Remote()..failFirestore = true;
    final repo = ProfileRepositoryImpl(remote);
    await expectLater(
        repo.updateDetails('uid', name: 'Maria', bio: 'Bio', nameChanged: true),
        throwsStateError);
    expect(remote.calls, ['firestore:uid:Maria:Bio']);
    remote.failFirestore = false;
    await repo.updateDetails('uid',
        name: 'Maria', bio: 'Bio', nameChanged: true);
    expect(remote.calls, [
      'firestore:uid:Maria:Bio',
      'firestore:uid:Maria:Bio',
      'auth:uid:Maria',
    ]);
  });

  test('falha do Auth sinaliza escrita parcial e tentativa seguinte conclui',
      () async {
    final remote = _Remote()..failAuth = true;
    final repo = ProfileRepositoryImpl(remote);
    await expectLater(
        repo.updateDetails('uid', name: 'Maria', bio: '', nameChanged: true),
        throwsA(isA<ProfileAuthSyncException>()));
    remote.failAuth = false;
    await repo.updateDetails('uid', name: 'Maria', bio: '', nameChanged: true);
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
        repo.updateDetails('uid', name: '   ', bio: '', nameChanged: true),
        throwsArgumentError);
    await expectLater(
        repo.updateDetails('uid', name: 'a' * 61, bio: '', nameChanged: true),
        throwsArgumentError);
    await expectLater(
        repo.updateDetails('uid',
            name: 'Ana', bio: 'a' * 161, nameChanged: false),
        throwsArgumentError);
    await repo.updateDetails('uid',
        name: 'Ana', bio: 'a' * 160, nameChanged: false);
    expect(remote.calls, ['firestore:uid:Ana:${'a' * 160}']);
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
            .save('uid', name: 'Ana Silva', bio: 'Basquete', nameChanged: true),
        isTrue);
    expect((await container.read(currentProfileProvider.future)).summary.name,
        'Ana Silva');
    expect((await container.read(publicProfileProvider('uid').future))!.bio,
        'Basquete');
    expect(container.read(greetingNameProvider), 'Ana Silva');

    // Um novo container força outra leitura, como ao voltar à conta.
    final newSession = ProviderContainer(overrides: [
      profileRepositoryProvider.overrideWith((_) => profiles),
      authStateProvider.overrideWith((_) => Stream.value(const AuthUser(
            uid: 'uid',
            email: 'privado@example.com',
            displayName: 'Ana Silva',
            hasUsername: true,
            hasFavoriteSports: true,
          ))),
    ]);
    addTearDown(newSession.dispose);
    await newSession.read(authStateProvider.future);
    final reloaded = await newSession.read(currentProfileProvider.future);
    expect(reloaded.summary.name, 'Ana Silva');
    expect(reloaded.bio, 'Basquete');
    expect(reloaded.summary.handle, '@ana');
    expect(reloaded.summary.avatarUrl, 'https://example.com/ana.jpg');
    expect(reloaded.favoriteSports, [Sport.volei]);
  });
}
