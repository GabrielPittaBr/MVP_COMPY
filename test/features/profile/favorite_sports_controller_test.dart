import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/profile/data/datasources/mock_profile.dart';
import 'package:mvp_compy/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/sport.dart';

const AuthUser _recemCadastrado = AuthUser(
  uid: 'u_gabriel',
  email: 'g@example.com',
  displayName: 'Gabriel',
  hasUsername: true,
  hasFavoriteSports: false,
);

/// Controller de auth com um estado inicial fixo — é o que o app tem em mãos
/// logo depois de `signUpWithEmail`.
class _AuthControllerComUsuario extends AuthController {
  @override
  Future<AuthUser?> build() async => _recemCadastrado;
}

void main() {
  setUp(() => MockProfile.favoriteSportsOverride = null);
  tearDown(() => MockProfile.favoriteSportsOverride = null);

  /// O router escuta `authControllerProvider` desde a abertura do app, então
  /// ele nunca está frio quando a tela de esportes grava. O fixture espera o
  /// `build()` para reproduzir isso — sem essa espera o teste mediria uma
  /// situação que não existe no app.
  Future<ProviderContainer> containerWith({required Override authState}) async {
    final container = ProviderContainer(
      overrides: <Override>[
        authState,
        authControllerProvider.overrideWith(_AuthControllerComUsuario.new),
        profileRepositoryProvider
            .overrideWith((_) => ProfileRepositoryImpl(null)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  Future<bool> save(ProviderContainer container, List<Sport> sports) =>
      container.read(favoriteSportsControllerProvider.notifier).save(sports);

  group('FavoriteSportsController.save', () {
    test('grava com o stream de auth já resolvido', () async {
      final container = await containerWith(
        authState: authStateProvider.overrideWith(
          (_) => Stream<AuthUser?>.value(_recemCadastrado),
        ),
      );

      expect(await save(container, const <Sport>[Sport.volei]), isTrue);
      expect(MockProfile.favoriteSportsOverride, <Sport>[Sport.volei]);
    });

    // O bug do cadastro real: quem acaba de criar conta tem um AuthUser bom no
    // controller, mas o stream pode estar em erro — basta a releitura de
    // `users/{uid}` disparada por `updateDisplayName` estourar o timeout.
    // Lendo só `authStateProvider.future`, o erro era repropagado e o cadastro
    // morria em "não foi possível salvar seus esportes" com a rede inteira boa.
    test('grava mesmo com o stream de auth em erro', () async {
      final container = await containerWith(
        authState: authStateProvider.overrideWith(
          (_) => Stream<AuthUser?>.error(Exception('leitura do perfil falhou')),
        ),
      );

      expect(await save(container, const <Sport>[Sport.corrida]), isTrue);
      expect(MockProfile.favoriteSportsOverride, <Sport>[Sport.corrida]);
    });

    test('o "pular" também sobrevive ao stream em erro', () async {
      final container = await containerWith(
        authState: authStateProvider.overrideWith(
          (_) => Stream<AuthUser?>.error(Exception('leitura do perfil falhou')),
        ),
      );

      expect(await save(container, const <Sport>[]), isTrue);
      expect(MockProfile.favoriteSportsOverride, isEmpty);
    });

    test('gravar avisa o guard que o onboarding acabou', () async {
      final container = await containerWith(
        authState: authStateProvider.overrideWith(
          (_) => Stream<AuthUser?>.value(_recemCadastrado),
        ),
      );

      await save(container, const <Sport>[Sport.futsal]);

      expect(
        container.read(authControllerProvider).valueOrNull?.hasFavoriteSports,
        isTrue,
      );
    });
  });
}
