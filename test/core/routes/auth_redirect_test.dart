import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';

void main() {
  // Os quatro estados que o guard precisa distinguir.
  const AuthUser semUsername = AuthUser(
    uid: 'u1',
    email: 'g@example.com',
    displayName: 'Gabriel',
    hasUsername: false,
    hasFavoriteSports: false,
  );
  const AuthUser semEsportes = AuthUser(
    uid: 'u1',
    email: 'g@example.com',
    displayName: 'Gabriel',
    hasUsername: true,
    hasFavoriteSports: false,
  );
  const AuthUser completo = AuthUser(
    uid: 'u1',
    email: 'g@example.com',
    displayName: 'Gabriel',
    hasUsername: true,
    hasFavoriteSports: true,
  );

  /// Rotas de dentro do app — as 5 abas e o que pende delas.
  const List<String> rotasDoApp = <String>[
    AppRoutes.home,
    AppRoutes.events,
    AppRoutes.chat,
    AppRoutes.profile,
    AppRoutes.profileFavoriteSports,
    AppRoutes.maps,
    '/events/abc',
  ];

  const List<String> todasAsRotas = <String>[
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.username,
    AppRoutes.onboardingSports,
    ...rotasDoApp,
  ];

  String? redirect(
    AuthUser? user,
    String location, {
    bool isLoading = false,
    bool hasError = false,
  }) =>
      authRedirect(
        user: user,
        isLoading: isLoading,
        hasError: hasError,
        location: location,
      );

  /// Segue os redirecionamentos até parar. Estoura se não parar — é assim que
  /// um loop se manifestaria.
  String settle(
    AuthUser? user,
    String from, {
    bool isLoading = false,
    bool hasError = false,
  }) {
    final List<String> visitadas = <String>[from];
    String atual = from;
    for (int i = 0; i < 10; i++) {
      final String? proxima =
          redirect(user, atual, isLoading: isLoading, hasError: hasError);
      if (proxima == null) return atual;
      if (visitadas.contains(proxima)) {
        fail('loop de redirecionamento: ${<String>[...visitadas, proxima]}');
      }
      visitadas.add(proxima);
      atual = proxima;
    }
    fail('redirecionamento não estabilizou: $visitadas');
  }

  group('estado carregando', () {
    test('segura na splash, venha de onde vier', () {
      for (final String rota in todasAsRotas) {
        expect(
          settle(null, rota, isLoading: true),
          AppRoutes.splash,
          reason: rota,
        );
      }
    });
  });

  group('deslogado', () {
    test('qualquer rota do app leva ao login', () {
      for (final String rota in <String>[AppRoutes.splash, ...rotasDoApp]) {
        expect(settle(null, rota), AppRoutes.login, reason: rota);
      }
    });

    test('o cadastro é alcançável — não é o app', () {
      expect(redirect(null, AppRoutes.signup), isNull);
    });

    // Sem uid não há o que gravar em nenhuma das duas telas: elas não podem
    // servir de porta lateral para dentro do fluxo de cadastro.
    test('as telas de onboarding não abrigam quem não está logado', () {
      expect(redirect(null, AppRoutes.username), AppRoutes.login);
      expect(redirect(null, AppRoutes.onboardingSports), AppRoutes.login);
    });
  });

  group('autenticado sem username (conta Google nova)', () {
    test('tudo converge para a escolha de username', () {
      for (final String rota in todasAsRotas) {
        expect(settle(semUsername, rota), AppRoutes.username, reason: rota);
      }
    });

    test('não pula direto para os esportes', () {
      expect(redirect(semUsername, AppRoutes.onboardingSports),
          AppRoutes.username);
    });
  });

  group('autenticado sem esportes', () {
    test('tudo converge para o onboarding de esportes', () {
      for (final String rota in todasAsRotas) {
        expect(
          settle(semEsportes, rota),
          AppRoutes.onboardingSports,
          reason: rota,
        );
      }
    });

    test('a Home fica fora de alcance até passar pela tela', () {
      expect(redirect(semEsportes, AppRoutes.home), AppRoutes.onboardingSports);
    });

    test('não volta para o username, que já foi resolvido', () {
      expect(
        redirect(semEsportes, AppRoutes.username),
        AppRoutes.onboardingSports,
      );
    });
  });

  group('cadastro completo', () {
    test('as telas de entrada dão passagem para a Home', () {
      for (final String rota in <String>[
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.username,
        AppRoutes.onboardingSports,
      ]) {
        expect(redirect(completo, rota), AppRoutes.home, reason: rota);
      }
    });

    test('as rotas do app ficam onde estão', () {
      for (final String rota in rotasDoApp) {
        expect(redirect(completo, rota), isNull, reason: rota);
      }
    });

    // Quem escolheu nenhum esporte também concluiu o onboarding: o sinal é o
    // campo existir, não a lista ter itens. Este é o caso do "pular".
    test('quem pulou a escolha entra no app como qualquer outro', () {
      expect(settle(completo, AppRoutes.splash), AppRoutes.home);
    });
  });

  group('falha ao ler o perfil', () {
    test('segura na splash em vez de deslogar ou recadastrar', () {
      for (final String rota in todasAsRotas) {
        expect(
          settle(null, rota, hasError: true),
          AppRoutes.splash,
          reason: rota,
        );
      }
    });

    // O erro não pode atropelar um usuário que o controller já resolveu —
    // é o caso de quem acabou de se cadastrar por e-mail.
    test('com usuário em mãos, o erro não muda o destino', () {
      expect(redirect(completo, AppRoutes.home, hasError: true), isNull);
      expect(
        settle(semEsportes, AppRoutes.home, hasError: true),
        AppRoutes.onboardingSports,
      );
    });
  });

  group('nenhum estado cicla', () {
    test('todo par (estado, rota) estabiliza', () {
      const List<AuthUser?> estados = <AuthUser?>[
        null,
        semUsername,
        semEsportes,
        completo,
      ];
      for (final AuthUser? estado in estados) {
        for (final String rota in todasAsRotas) {
          for (final bool erro in <bool>[false, true]) {
            settle(estado, rota, hasError: erro);
          }
        }
      }
    });
  });
}
