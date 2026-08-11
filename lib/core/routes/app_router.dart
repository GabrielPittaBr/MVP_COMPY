import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/username_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/chat/presentation/pages/chat_room_page.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/chat/presentation/pages/new_conversation_page.dart';
import '../../features/events/presentation/pages/create_event_page.dart';
import '../../features/events/presentation/pages/event_detail_page.dart';
import '../../features/events/presentation/pages/events_list_page.dart';
import '../../features/events/presentation/pages/search_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/maps/presentation/pages/maps_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/favorite_sports_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../shared/pages/under_construction_page.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../constants/app_strings.dart';

/// Caminhos das principais telas — centralizados para evitar strings espalhadas.
abstract final class AppRoutes {
  // Splash (carregamento inicial)
  static const String splash = '/';

  // Auth (fora do shell — sem bottom nav)
  static const String login = '/login';
  static const String signup = '/signup';
  static const String username = '/username';
  static const String onboardingSports = '/onboarding/esportes';

  // App (dentro do shell com 5 abas)
  static const String home = '/home';
  static const String events = '/events';
  static const String eventDetail = '/events/:id';
  static const String create = '/create';
  static const String chat = '/chat';
  static const String chatRoom = '/chat/:conversationId';
  static const String chatNew = '/chat/nova';
  static const String profile = '/profile';

  /// Edição dos esportes favoritos — sub-rota do perfil, dentro do shell.
  /// Separada de [onboardingSports] porque o guard manda quem já concluiu o
  /// cadastro para longe das rotas de onboarding: quem edita já concluiu.
  static const String profileFavoriteSports = '/profile/esportes';

  /// Edição do perfil — sub-rota do perfil, dentro do shell.
  static const String profileEdit = '/profile/editar';

  /// Mapa fica como sub-rota da home para preservar o bottom nav (mockup).
  static const String maps = '/home/maps';

  /// Busca de eventos — sub-rota da home (aberta pelo SearchField).
  static const String search = '/home/search';

  /// Configurações — o botão da Home já existe; a tela, ainda não.
  static const String settings = '/home/configuracoes';

  /// Insígnias — o "Ver mais" do perfil já existe; a tela, ainda não.
  static const String profileBadges = '/profile/insignias';
}

/// Rotas abertas a quem ainda não está autenticado.
const Set<String> _publicRoutes = <String>{AppRoutes.login, AppRoutes.signup};

/// Rotas de quem já está autenticado mas ainda não terminou de entrar.
/// Ficam fora do shell — não têm bottom nav e não são "o app" ainda.
const Set<String> _onboardingRoutes = <String>{
  AppRoutes.username,
  AppRoutes.onboardingSports,
};

/// Para onde o usuário deve ir, dado o estado de autenticação e onde ele
/// está. `null` = fica onde está.
///
/// Separada do [GoRouter] de propósito: é a decisão mais sensível do app —
/// errar aqui tranca o usuário fora ou em loop — e como função pura ela é
/// testável sem construir uma única tela. Ver
/// `test/core/routes/auth_redirect_test.dart`, que percorre os quatro
/// estados a partir de toda rota e prova que nenhum caminho cicla.
///
/// A ordem dos degraus é o contrato: autenticar, depois username, depois
/// esportes, depois entrar. Cada degrau só é avaliado quando o anterior
/// está satisfeito.
@visibleForTesting
String? authRedirect({
  required AuthUser? user,
  required bool isLoading,
  required bool hasError,
  required String location,
}) {
  // Estado de auth ainda carregando: splash.
  if (isLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  // Leitura de `users/{uid}` falhou: há alguém logado, mas não dá para saber
  // em que ponto do cadastro ele está. Fica na splash, que oferece nova
  // tentativa — mandar para /login deslogaria quem está autenticado, e
  // mandar para /username faria recadastrar quem já tem conta.
  if (user == null && hasError) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  // Não autenticado → /login. Nem /username nem /onboarding servem de
  // esconderijo: sem uid não há o que gravar em nenhuma das duas.
  if (user == null) {
    return _publicRoutes.contains(location) ? null : AppRoutes.login;
  }

  // Autenticado sem username (conta Google nova) → /username.
  if (!user.hasUsername) {
    return location == AppRoutes.username ? null : AppRoutes.username;
  }

  // Com username e sem ter passado pelos esportes → /onboarding/esportes.
  if (!user.hasFavoriteSports) {
    return location == AppRoutes.onboardingSports
        ? null
        : AppRoutes.onboardingSports;
  }

  // Cadastro completo: nada de ficar parado na splash nem nas telas de
  // entrada, que já cumpriram seu papel.
  if (location == AppRoutes.splash ||
      _publicRoutes.contains(location) ||
      _onboardingRoutes.contains(location)) {
    return AppRoutes.home;
  }

  return null;
}

/// Provider que expõe o router para o `MaterialApp.router`.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _RouterNotifier();

  // Notifica o router via ref.listen, garantindo que authStateProvider
  // já está atualizado quando o redirect roda (evita race condition).
  ref.listen<AsyncValue<AuthUser?>>(
    authStateProvider,
    (_, __) => authNotifier.notify(),
  );
  ref.listen<AsyncValue<AuthUser?>>(
    authControllerProvider,
    (_, __) => authNotifier.notify(),
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,

    // ── Guard de autenticação ────────────────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AuthUser?> authAsync = ref.read(authStateProvider);
      final AsyncValue<AuthUser?> controllerAsync =
          ref.read(authControllerProvider);

      // O estado do controller tem prioridade sobre o stream para evitar
      // a race condition no cadastro por e-mail (authStateChanges dispara
      // antes do perfil ser gravado no Firestore) e para o onboarding de
      // esportes valer imediatamente, sem esperar o stream reemitir.
      final AuthUser? user =
          controllerAsync.valueOrNull ?? authAsync.valueOrNull;

      return authRedirect(
        user: user,
        isLoading: authAsync.isLoading && user == null,
        // `authAsync` só entra em erro com usuário logado: deslogado emite
        // null sem passar pela leitura do perfil.
        hasError: authAsync.hasError,
        location: state.uri.path,
      );
    },

    routes: <RouteBase>[
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // ── Rotas de autenticação (fora do shell — sem bottom nav) ─────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: AppRoutes.username,
        builder: (context, state) {
          // Passa o AuthUser atual para a tela de username.
          // Se por algum motivo for null aqui (improvável após redirect),
          // volta para /login.
          final AuthUser? user = ref.read(authStateProvider).valueOrNull;
          if (user == null) {
            return const LoginPage();
          }
          return UsernamePage(user: user);
        },
      ),

      GoRoute(
        path: AppRoutes.onboardingSports,
        builder: (context, state) => const FavoriteSportsPage(),
      ),

      // ── Shell com bottom nav preservando estado entre as 5 abas (RNF07) ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) =>
            _ScaffoldWithNavBar(navShell: navShell),
        branches: <StatefulShellBranch>[
          // Branch 0 — Início + Mapa (mantém bottom nav no mapa)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'maps',
                    // `extra` traz o id do local a abrir selecionado — é por
                    // aqui que o local encaminhado no chat volta ao pin.
                    builder: (context, state) =>
                        MapsPage(initialPlaceId: state.extra as String?),
                  ),
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchPage(),
                  ),
                  GoRoute(
                    path: 'configuracoes',
                    builder: (context, state) => const UnderConstructionPage(
                      title: AppStrings.settingsTitle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Eventos (lista + detalhes)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.events,
                builder: (context, state) => const EventsListPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        EventDetailPage(eventId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Criar
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.create,
                // `extra` opcional: id do local vindo do pin do mapa
                // (bottom sheet → "Criar evento"). Sem ele, formulário
                // em branco como sempre.
                builder: (context, state) =>
                    CreateEventPage(initialPlaceId: state.extra as String?),
              ),
            ],
          ),
          // Branch 3 — Chat (lista + sala)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.chat,
                builder: (context, state) => const ConversationsPage(),
                routes: <RouteBase>[
                  // Declarada antes de `:conversationId`: o GoRouter casa as
                  // rotas na ordem, e sem isso "nova" seria lido como id de
                  // conversa.
                  GoRoute(
                    path: 'nova',
                    builder: (context, state) => const NewConversationPage(),
                  ),
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ChatRoomPage(
                      conversationId: state.pathParameters['conversationId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 4 — Perfil
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'esportes',
                    builder: (context, state) => const FavoriteSportsPage(
                      mode: FavoriteSportsMode.edit,
                    ),
                  ),
                  GoRoute(
                    path: 'insignias',
                    builder: (context, state) => const UnderConstructionPage(
                      title: AppStrings.profileBadges,
                    ),
                  ),
                  GoRoute(
                    path: 'editar',
                    builder: (context, state) => const EditProfilePage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navShell});

  final StatefulNavigationShell navShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navShell.currentIndex,
        // `goBranch` preserva o estado da aba (RNF07): voltar para "Eventos"
        // não recria a página, mantém scroll e detalhes anteriores.
        onTap: (index) => navShell.goBranch(
          index,
          initialLocation: index == navShell.currentIndex,
        ),
      ),
    );
  }
}

class _RouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
