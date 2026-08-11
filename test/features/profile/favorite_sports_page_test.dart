import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/profile/data/datasources/mock_profile.dart';
import 'package:mvp_compy/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:mvp_compy/features/profile/domain/entities/rating_summary.dart';
import 'package:mvp_compy/features/profile/domain/entities/user_profile.dart';
import 'package:mvp_compy/features/profile/presentation/pages/favorite_sports_page.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

void main() {
  // O repositório sem datasource remoto grava em `MockProfile`, então é ele
  // que responde por "o que ficou salvo" ao longo dos testes.
  setUp(() => MockProfile.favoriteSportsOverride = null);
  tearDown(() => MockProfile.favoriteSportsOverride = null);

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

  /// A tela tem 8 ladrilhos e dois botões — precisa de altura para caber sem
  /// rolar, senão o "pular" nem chega a ser construído.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<GoRouter> pumpRouter(
    WidgetTester tester,
    GoRouter router, {
    List<Sport> saved = const <Sport>[],
    bool tallViewport = true,
    double textScale = 1,
  }) async {
    if (tallViewport) useTallViewport(tester);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authStateProvider.overrideWith(
            (_) => Stream<AuthUser?>.value(
              const AuthUser(
                uid: 'u_gabriel',
                email: 'g@example.com',
                displayName: 'Gabriel',
                hasUsername: true,
                hasFavoriteSports: false,
              ),
            ),
          ),
          // `null` força o ramo mock do repositório — a escrita cai em
          // `MockProfile.favoriteSportsOverride`.
          profileRepositoryProvider
              .overrideWith((_) => ProfileRepositoryImpl(null)),
          currentProfileProvider.overrideWith((_) async => profileWith(saved)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<GoRouter> pumpPage(
    WidgetTester tester, {
    List<Sport> saved = const <Sport>[],
  }) =>
      pumpRouter(
        tester,
        GoRouter(
          initialLocation: AppRoutes.onboardingSports,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.onboardingSports,
              builder: (_, __) => const FavoriteSportsPage(),
            ),
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const Scaffold(body: Text('home')),
            ),
          ],
        ),
        saved: saved,
      );

  /// A edição é empilhada sobre o perfil, como no app: o retorno esperado do
  /// "Salvar" é um pop, não uma navegação.
  Future<GoRouter> pumpEditPage(
    WidgetTester tester, {
    List<Sport> saved = const <Sport>[],
  }) async {
    final router = await pumpRouter(
      tester,
      GoRouter(
        initialLocation: AppRoutes.profile,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const Scaffold(body: Text('perfil')),
            routes: <RouteBase>[
              GoRoute(
                path: 'esportes',
                builder: (_, __) => const FavoriteSportsPage(
                  mode: FavoriteSportsMode.edit,
                ),
              ),
            ],
          ),
        ],
      ),
      saved: saved,
    );
    router.push(AppRoutes.profileFavoriteSports);
    await tester.pumpAndSettle();
    return router;
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  Finder tileFor(Sport sport) => find.text(sport.label);

  group('FavoriteSportsPage', () {
    testWidgets('abre com o convite de personalizar o perfil', (tester) async {
      await pumpPage(tester);
      expect(find.text(AppStrings.onboardingSportsTitle), findsOneWidget);
    });

    testWidgets('mostra todas as modalidades do enum', (tester) async {
      await pumpPage(tester);
      for (final sport in Sport.values) {
        expect(tileFor(sport), findsOneWidget, reason: sport.label);
      }
    });

    testWidgets('"Continuar" nasce desabilitado e liga no primeiro esporte',
        (tester) async {
      await pumpPage(tester);

      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);

      await tester.tap(tileFor(Sport.corrida));
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('desmarcar o último esporte desabilita "Continuar" de novo',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(tileFor(Sport.corrida));
      await tester.pump();
      await tester.tap(tileFor(Sport.corrida));
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a escolha é gravada e a tela sai para a Home', (tester) async {
      final router = await pumpPage(tester);

      await tester.tap(tileFor(Sport.volei));
      await tester.tap(tileFor(Sport.ciclismo));
      await tester.pump();
      await tester.tap(find.text(AppStrings.onboardingSportsContinue));
      await tester.pumpAndSettle();

      expect(
        MockProfile.favoriteSportsOverride,
        <Sport>[Sport.volei, Sport.ciclismo],
      );
      expect(location(router), AppRoutes.home);
    });

    // O campo precisa passar a existir mesmo sem esporte nenhum: é a presença
    // dele que diz ao guard que o onboarding acabou.
    testWidgets('"pular" grava lista vazia — não deixa de gravar',
        (tester) async {
      final router = await pumpPage(tester);

      await tester.tap(find.text(AppStrings.onboardingSportsSkip));
      await tester.pumpAndSettle();

      expect(MockProfile.favoriteSportsOverride, isEmpty);
      expect(MockProfile.favoriteSportsOverride, isNotNull);
      expect(location(router), AppRoutes.home);
    });

    testWidgets('abre com as escolhas já salvas marcadas', (tester) async {
      await pumpPage(tester, saved: const <Sport>[Sport.futsal]);

      // Só o já escolhido conta como seleção: "Continuar" já nasce ligado.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text(AppStrings.onboardingSportsContinue));
      await tester.pumpAndSettle();
      expect(MockProfile.favoriteSportsOverride, <Sport>[Sport.futsal]);
    });
  });

  group('FavoriteSportsPage — layout', () {
    // Aparelho de verdade — 411x914 lógicos, o do relato: com 4 colunas a
    // célula fica estreita e "Tênis de mesa" precisa de duas linhas.
    //
    // A fonte ampliada não é capricho do teste: a fonte do ambiente de teste
    // tem métrica diferente da do aparelho, e no tamanho padrão ela cabia
    // mesmo na célula curta que estourou na mão do usuário. Ampliar recria a
    // pressão que a fonte real faz — e cobre de brinde quem usa o app com a
    // fonte do sistema aumentada.
    // 2x fica de fora: com a fonte do sistema no dobro, título e botões
    // sozinhos já não cabem na tela, e resolver isso é remontar o layout da
    // página — outro trabalho, não este conserto.
    for (final double escala in <double>[1, 1.3]) {
      testWidgets('cabe num aparelho estreito com fonte ${escala}x, sem overflow',
          (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);

        await pumpRouter(
          tester,
          GoRouter(
            initialLocation: AppRoutes.onboardingSports,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.onboardingSports,
                builder: (_, __) => const FavoriteSportsPage(),
              ),
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const Scaffold(body: Text('home')),
              ),
            ],
          ),
          tallViewport: false,
          textScale: escala,
        );

        // `pumpWidget` já teria estourado no overflow; a checagem explícita
        // deixa o motivo da falha legível.
        expect(tester.takeException(), isNull);

        // E as 8 modalidades continuam todas na tela.
        for (final sport in Sport.values) {
          expect(find.text(sport.label), findsOneWidget, reason: sport.label);
        }
      });
    }
  });

  group('FavoriteSportsPage — edição pelo perfil', () {
    testWidgets('abre com as escolhas atuais marcadas', (tester) async {
      await pumpEditPage(tester, saved: const <Sport>[Sport.volei]);

      await tester.tap(find.text(AppStrings.onboardingSportsSave));
      await tester.pumpAndSettle();
      expect(MockProfile.favoriteSportsOverride, <Sport>[Sport.volei]);
    });

    testWidgets('não oferece "pular" — já dá para voltar atrás',
        (tester) async {
      await pumpEditPage(tester, saved: const <Sport>[Sport.volei]);
      expect(find.text(AppStrings.onboardingSportsSkip), findsNothing);
    });

    testWidgets('salvar volta para o perfil', (tester) async {
      final router = await pumpEditPage(tester, saved: const <Sport>[Sport.volei]);

      await tester.tap(find.text(AppStrings.onboardingSportsSave));
      await tester.pumpAndSettle();

      expect(location(router), AppRoutes.profile);
      expect(find.text('perfil'), findsOneWidget);
    });

    testWidgets('a edição substitui a escolha anterior', (tester) async {
      await pumpEditPage(tester, saved: const <Sport>[Sport.volei]);

      await tester.tap(tileFor(Sport.volei)); // desmarca
      await tester.tap(tileFor(Sport.corrida)); // marca
      await tester.pump();
      await tester.tap(find.text(AppStrings.onboardingSportsSave));
      await tester.pumpAndSettle();

      expect(MockProfile.favoriteSportsOverride, <Sport>[Sport.corrida]);
    });

    // Limpar tudo é edição legítima e não desfaz o onboarding: o que o guard
    // olha é o campo existir, não a lista ter itens.
    testWidgets('dá para limpar tudo — "Salvar" continua habilitado',
        (tester) async {
      await pumpEditPage(tester, saved: const <Sport>[Sport.volei]);

      await tester.tap(tileFor(Sport.volei));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text(AppStrings.onboardingSportsSave));
      await tester.pumpAndSettle();
      expect(MockProfile.favoriteSportsOverride, isEmpty);
    });

    testWidgets('sair sem salvar não altera nada', (tester) async {
      final router = await pumpEditPage(tester, saved: const <Sport>[Sport.volei]);

      await tester.tap(tileFor(Sport.corrida));
      await tester.pump();
      router.pop();
      await tester.pumpAndSettle();

      expect(MockProfile.favoriteSportsOverride, isNull);
      expect(location(router), AppRoutes.profile);
    });
  });
}
