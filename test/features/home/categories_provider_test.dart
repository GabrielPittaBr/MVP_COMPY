import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/home/data/repositories/home_repository_impl.dart';
import 'package:mvp_compy/features/home/domain/entities/sport_category.dart';
import 'package:mvp_compy/features/home/presentation/providers/home_providers.dart';
import 'package:mvp_compy/features/profile/domain/entities/rating_summary.dart';
import 'package:mvp_compy/features/profile/domain/entities/user_profile.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

void main() {
  UserProfile profileWith(List<Sport> sports) => UserProfile(
        summary: const UserSummary(
          id: 'u_gabriel',
          name: 'Gabriel',
          handle: '@gabriel',
          avatarUrl: '',
        ),
        bio: '',
        favoriteSports: sports,
        badges: const [],
        friends: const [],
        rating: const RatingSummary(average: 0, count: 0, breakdown: {}),
        gallery: const [],
      );

  /// `getCategories` não toca o datasource, então o repositório sem remoto é
  /// o mesmo código que roda no app — só sem precisar de Firebase.
  ProviderContainer containerWith(Override profileOverride) {
    final container = ProviderContainer(
      overrides: <Override>[
        homeRepositoryProvider.overrideWith((_) => HomeRepositoryImpl(null)),
        profileOverride,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  List<Sport> sportsOf(List<SportCategory> categories) =>
      categories.map((c) => c.sport).toList();

  group('categoriesProvider', () {
    test('segue os esportes favoritos do perfil, na ordem escolhida', () async {
      final container = containerWith(
        currentProfileProvider.overrideWith(
          (_) async => profileWith(const <Sport>[Sport.corrida, Sport.futsal]),
        ),
      );
      await container.read(currentProfileProvider.future);

      expect(
        sportsOf(container.read(categoriesProvider)),
        <Sport>[Sport.corrida, Sport.futsal],
      );
    });

    test('quem pulou o onboarding vê o trio padrão', () async {
      final container = containerWith(
        currentProfileProvider.overrideWith((_) async => profileWith(const [])),
      );
      await container.read(currentProfileProvider.future);

      expect(
        sportsOf(container.read(categoriesProvider)),
        <Sport>[Sport.futebol, Sport.basquete, Sport.volei],
      );
    });

    // A Home não pode ficar em branco esperando o perfil: mostra o padrão e
    // troca sozinha quando os favoritos chegam.
    test('com o perfil ainda carregando, mostra o trio padrão', () {
      final container = containerWith(
        currentProfileProvider.overrideWith(
          (_) => Future<UserProfile>.delayed(
            const Duration(seconds: 1),
            () => profileWith(const <Sport>[Sport.corrida]),
          ),
        ),
      );

      expect(
        sportsOf(container.read(categoriesProvider)),
        <Sport>[Sport.futebol, Sport.basquete, Sport.volei],
      );
    });

    test('o carrossel troca sozinho quando os favoritos chegam', () async {
      final container = containerWith(
        currentProfileProvider.overrideWith(
          (_) async => profileWith(const <Sport>[Sport.ciclismo]),
        ),
      );

      expect(sportsOf(container.read(categoriesProvider)), hasLength(3));

      await container.read(currentProfileProvider.future);

      expect(
        sportsOf(container.read(categoriesProvider)),
        <Sport>[Sport.ciclismo],
      );
    });

    test('perfil em erro não derruba a Home — cai no trio padrão', () async {
      final container = containerWith(
        currentProfileProvider
            .overrideWith((_) async => throw Exception('sem rede')),
      );
      await expectLater(
        container.read(currentProfileProvider.future),
        throwsException,
      );

      expect(sportsOf(container.read(categoriesProvider)), hasLength(3));
    });
  });
}
