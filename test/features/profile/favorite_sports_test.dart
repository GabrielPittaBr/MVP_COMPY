import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/profile/data/datasources/mock_profile.dart';
import 'package:mvp_compy/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:mvp_compy/shared/models/sport.dart';

void main() {
  // Sem datasource remoto o repositório serve o perfil mockado — mesmo
  // caminho que o app usa com `kUseFirebaseRepos = false`.
  final repository = ProfileRepositoryImpl(null);

  setUp(() => MockProfile.favoriteSportsOverride = null);
  tearDown(() => MockProfile.favoriteSportsOverride = null);

  group('ProfileRepositoryImpl.updateFavoriteSports', () {
    test('a escolha gravada é a que o perfil passa a mostrar', () async {
      await repository.updateFavoriteSports(
        'u_joao',
        const <Sport>[Sport.corrida, Sport.ciclismo],
      );

      final profile = await repository.getCurrentProfile('u_joao');
      expect(profile.favoriteSports, <Sport>[Sport.corrida, Sport.ciclismo]);
    });

    test('escolher nenhum esporte é escolha válida — é o que o pular grava',
        () async {
      await repository.updateFavoriteSports('u_joao', const <Sport>[]);

      final profile = await repository.getCurrentProfile('u_joao');
      expect(profile.favoriteSports, isEmpty);
    });

    test('regravar substitui a escolha anterior, não acumula', () async {
      await repository.updateFavoriteSports('u_joao', const <Sport>[Sport.volei]);
      await repository.updateFavoriteSports('u_joao', const <Sport>[Sport.futsal]);

      final profile = await repository.getCurrentProfile('u_joao');
      expect(profile.favoriteSports, <Sport>[Sport.futsal]);
    });

    test('sem escolha registrada o perfil mantém a lista de fábrica', () async {
      final profile = await repository.getCurrentProfile('u_joao');
      expect(profile.favoriteSports, isNotEmpty);
    });
  });
}
